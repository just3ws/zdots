package drain

import (
	"bufio"
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"net"
	"strconv"
	"strings"

	_ "github.com/mattn/go-sqlite3"
)

// CommandRun matches the SQLite schema in conf.d/56-cmd-analytics.zsh
type CommandRun struct {
	SessionID  string `json:"session_id"`
	Ts         int64  `json:"ts"`
	Cwd        string `json:"cwd"`
	Cmd        string `json:"cmd"`
	Args       string `json:"args"`
	ExitCode   int    `json:"exit_code"`
	DurationMs int    `json:"duration_ms"`
	Profile    string `json:"profile"`
}

// Result reports the outcome of a drain operation.
type Result struct {
	Drained     int    `json:"drained"`
	Keys        int    `json:"keys_processed"`
	Errors      int    `json:"errors"`
	DelFailures int    `json:"del_failures"`
	Message     string `json:"message,omitempty"`
}

// Drainer holds configuration and dependencies
type Drainer struct {
	dbPath    string
	redisAddr string
	dryRun    bool
}

// Option is a functional option for Drainer
type Option func(*Drainer)

func WithDBPath(path string) Option {
	return func(d *Drainer) {
		d.dbPath = path
	}
}

func WithRedisAddr(addr string) Option {
	return func(d *Drainer) {
		d.redisAddr = addr
	}
}

func WithDryRun(dryRun bool) Option {
	return func(d *Drainer) {
		d.dryRun = dryRun
	}
}

// New creates a new Drainer
func New(opts ...Option) *Drainer {
	d := &Drainer{
		dbPath:    "/tmp/history.sqlite3",
		redisAddr: "127.0.0.1:6379",
		dryRun:    false,
	}
	for _, opt := range opts {
		opt(d)
	}
	return d
}

// Redis RESP protocol utilities (simple hand-rolled implementation)
type respClient struct {
	conn   net.Conn
	reader *bufio.Reader
	writer *bufio.Writer
}

func dialRedis(addr string) (*respClient, error) {
	conn, err := net.DialTimeout("tcp", addr, 5*1e9) // 5 second timeout
	if err != nil {
		return nil, err
	}
	return &respClient{
		conn:   conn,
		reader: bufio.NewReader(conn),
		writer: bufio.NewWriter(conn),
	}, nil
}

func (rc *respClient) Close() error {
	return rc.conn.Close()
}

func (rc *respClient) Ping() error {
	if _, err := rc.writer.WriteString("PING\r\n"); err != nil {
		return err
	}
	if err := rc.writer.Flush(); err != nil {
		return err
	}

	// Read response: should be +PONG
	line, err := rc.reader.ReadString('\n')
	if err != nil {
		return err
	}
	if !strings.HasPrefix(strings.TrimSpace(line), "+PONG") {
		return fmt.Errorf("unexpected PING response: %s", line)
	}
	return nil
}

// Scan execcts Redis SCAN pattern. Returns keys and the new cursor.
func (rc *respClient) Scan(cursor int, pattern string, count int) ([]string, int, error) {
	cmd := fmt.Sprintf("*4\r\n$4\r\nSCAN\r\n$%d\r\n%d\r\n$5\r\nMATCH\r\n$%d\r\n%s\r\n",
		len(strconv.Itoa(cursor)), cursor, len(pattern), pattern)
	if _, err := rc.writer.WriteString(cmd); err != nil {
		return nil, 0, err
	}
	if err := rc.writer.Flush(); err != nil {
		return nil, 0, err
	}

	// Read response (array with 2 elements: cursor (bulk string) + keys list)
	line, err := rc.readLine()
	if err != nil {
		return nil, 0, err
	}
	if !strings.HasPrefix(line, "*2") {
		return nil, 0, fmt.Errorf("expected *2 array response, got: %s", line)
	}

	// Read cursor (bulk string)
	cursorLine, err := rc.readLine()
	if err != nil {
		return nil, 0, err
	}
	if !strings.HasPrefix(cursorLine, "$") {
		return nil, 0, fmt.Errorf("expected cursor bulk string, got: %s", cursorLine)
	}
	size, _ := strconv.Atoi(cursorLine[1:])
	cursorBuf := make([]byte, size)
	if _, err := rc.reader.Read(cursorBuf); err != nil {
		return nil, 0, err
	}
	rc.reader.ReadByte() // \r
	rc.reader.ReadByte() // \n

	newCursor, err := strconv.Atoi(string(cursorBuf))
	if err != nil {
		return nil, 0, err
	}

	// Read keys array
	keysLine, err := rc.readLine()
	if err != nil {
		return nil, 0, err
	}
	if !strings.HasPrefix(keysLine, "*") {
		return nil, 0, fmt.Errorf("expected keys array, got: %s", keysLine)
	}
	keyCount, _ := strconv.Atoi(keysLine[1:])

	var keys []string
	for i := 0; i < keyCount; i++ {
		keyLine, err := rc.readLine()
		if err != nil {
			return nil, 0, err
		}
		if strings.HasPrefix(keyLine, "$") {
			size, _ := strconv.Atoi(keyLine[1:])
			if size > 0 {
				keyBuf := make([]byte, size)
				if _, err := rc.reader.Read(keyBuf); err != nil {
					return nil, 0, err
				}
				rc.reader.ReadByte() // \r
				rc.reader.ReadByte() // \n
				keys = append(keys, string(keyBuf))
			}
		}
	}

	return keys, newCursor, nil
}

// LRange executes LRANGE key 0 -1 (all entries)
func (rc *respClient) LRange(key string) ([]string, error) {
	cmd := fmt.Sprintf("*4\r\n$6\r\nLRANGE\r\n$%d\r\n%s\r\n$1\r\n0\r\n$2\r\n-1\r\n", len(key), key)
	if _, err := rc.writer.WriteString(cmd); err != nil {
		return nil, err
	}
	if err := rc.writer.Flush(); err != nil {
		return nil, err
	}

	resp, err := rc.readArray()
	if err != nil {
		return nil, err
	}

	var entries []string
	for _, item := range resp {
		if s, ok := item.(string); ok {
			entries = append(entries, s)
		}
	}
	return entries, nil
}

// Del executes DEL key
func (rc *respClient) Del(key string) error {
	cmd := fmt.Sprintf("*2\r\n$3\r\nDEL\r\n$%d\r\n%s\r\n", len(key), key)
	if _, err := rc.writer.WriteString(cmd); err != nil {
		return err
	}
	if err := rc.writer.Flush(); err != nil {
		return err
	}

	// Read response (integer)
	_, err := rc.readLine()
	return err
}

func (rc *respClient) readArray() ([]interface{}, error) {
	line, err := rc.readLine()
	if err != nil {
		return nil, err
	}

	if !strings.HasPrefix(line, "*") {
		return nil, fmt.Errorf("expected array, got: %s", line)
	}

	count, err := strconv.Atoi(line[1:])
	if err != nil {
		return nil, err
	}

	var result []interface{}
	for i := 0; i < count; i++ {
		line, err := rc.readLine()
		if err != nil {
			return nil, err
		}

		if strings.HasPrefix(line, "$") {
			// Bulk string
			size, _ := strconv.Atoi(line[1:])
			if size == -1 {
				result = append(result, nil)
				continue
			}

			buf := make([]byte, size)
			if _, err := rc.reader.Read(buf); err != nil {
				return nil, err
			}
			rc.reader.ReadByte() // \r
			rc.reader.ReadByte() // \n

			result = append(result, string(buf))
		}
	}
	return result, nil
}

func (rc *respClient) readLine() (string, error) {
	line, err := rc.reader.ReadString('\n')
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(line), nil
}

// Drain performs the drain operation: scan Redis, parse JSON, insert into SQLite, delete Redis keys.
func (d *Drainer) Drain(ctx context.Context) (*Result, error) {
	result := &Result{}

	// Connect to Redis
	rc, err := dialRedis(d.redisAddr)
	if err != nil {
		result.Message = fmt.Sprintf("Redis unavailable at %s, nothing to drain", d.redisAddr)
		return result, nil
	}
	defer rc.Close()

	// Check Redis connectivity
	if err := rc.Ping(); err != nil {
		result.Message = fmt.Sprintf("Redis unavailable at %s, nothing to drain", d.redisAddr)
		return result, nil
	}

	// Scan for all zdots:cmds:* keys
	var keys []string
	cursor := 0
	for {
		batch, newCursor, err := rc.Scan(cursor, "zdots:cmds:*", 100)
		if err != nil {
			return result, fmt.Errorf("Redis SCAN failed: %w", err)
		}
		keys = append(keys, batch...)
		cursor = newCursor
		if cursor == 0 {
			break
		}
	}

	if len(keys) == 0 {
		result.Message = "No Redis keys to drain"
		return result, nil
	}

	// Open SQLite database
	db, err := sql.Open("sqlite3", d.dbPath)
	if err != nil {
		return result, fmt.Errorf("SQLite open failed: %w", err)
	}
	defer db.Close()

	// Begin transaction
	txn, err := db.BeginTx(ctx, nil)
	if err != nil {
		return result, fmt.Errorf("SQLite transaction begin failed: %w", err)
	}
	defer txn.Rollback()

	// Process each Redis key
	for _, key := range keys {
		result.Keys++

		// Fetch all entries from Redis
		entries, err := rc.LRange(key)
		if err != nil {
			result.Errors++
			continue
		}

		// Parse JSON entries and insert into SQLite
		for _, entry := range entries {
			var run CommandRun
			if err := json.Unmarshal([]byte(entry), &run); err != nil {
				result.Errors++
				continue
			}

			if run.Cmd == "" {
				continue // skip empty commands
			}

			if !d.dryRun {
				// INSERT OR IGNORE to handle duplicate drains gracefully
				_, err := txn.ExecContext(ctx,
					`INSERT OR IGNORE INTO command_runs(session_id, ts, cwd, cmd, args, exit_code, duration_ms, profile)
					 VALUES(?, ?, ?, ?, ?, ?, ?, ?)`,
					run.SessionID, run.Ts, run.Cwd, run.Cmd, run.Args, run.ExitCode, run.DurationMs, run.Profile,
				)
				if err != nil {
					result.Errors++
					continue
				}
			}
			result.Drained++
		}

		// After successful SQLite write, delete the Redis key
		if !d.dryRun {
			if err := rc.Del(key); err != nil {
				result.DelFailures++
				// Continue despite DEL failure — key will be retried on next drain
			}
		}
	}

	// Commit transaction
	if !d.dryRun {
		if err := txn.Commit(); err != nil {
			return result, fmt.Errorf("SQLite commit failed: %w", err)
		}
	}

	if result.Errors > 0 {
		result.Message = fmt.Sprintf("Drained %d rows from %d keys with %d errors, %d DEL failures",
			result.Drained, result.Keys, result.Errors, result.DelFailures)
	} else {
		result.Message = fmt.Sprintf("Drained %d rows from %d keys", result.Drained, result.Keys)
	}

	return result, nil
}
