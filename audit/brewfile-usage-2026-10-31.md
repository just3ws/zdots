# Brewfile Usage Audit — 2026-10-31

Review-only report for a rolling 90-day Atuin history window.

## Method

- Read Atuin history from `/Users/mike/.local/share/atuin/history.db` using SQLite read-only mode.
- Queried 3,653 non-deleted history rows in the window (11,241 total rows). Raw command strings, working directories, and session identifiers are never written to this report.
- Mapped declared formulas through Homebrew `opt` links (including aliases) to executable files under each installed formula’s `bin`, `sbin`, and `libexec/bin` directories.
- Counted top-level command invocations by executable basename. Shared executable names count as use for every provider. Shell aliases/functions and background/service use can be missed; zero-use rows are review candidates, never uninstall instructions.
- Casks are not evaluated by shell history. Work-only formulae not installed on this host are listed separately, not treated as zero-use candidates.

## Summary

- Installed Homebrew leaves: 198.
- Declared formulas across common, home, work, and optional Rails profiles: 229.
- Installed declared formulas with executable files: 200.
- Review candidates with no direct invocation in this window: 169.
- Declared formulas not installed on this host: 13.
- Installed formulas without a CLI binary in scanned directories: 16.

## Operational exceptions

- `nginx` is a root-managed local reverse proxy. Its live server blocks route `zdots.localhost`, `my.localhost`, `o2.localhost`, Hister, Gemstash, media-pipeline, Jaeger, and related application endpoints. It is core platform plumbing even if its command is absent from Atuin history; restarting it requires operator `sudo` and is outside this audit.
- Local execution policy is bare metal. Dockerfiles remain valid for remote Fly deployments; local container runtimes and `act` are review candidates unless an explicit local workflow still requires them.
- The Docker CLI may still be useful for remote build/deploy tooling, but its presence alone does not justify a local VM or container runtime.
- Homebrew services marked `started` are excluded from zero-use candidates.
- Platform and repo-wrapper exceptions are excluded even when Atuin records the wrapper name instead of the Homebrew executable.

## Review candidates

| Formula | Profile(s) | Provided executable names |
| --- | --- | --- |
| actionlint | common, home, work | actionlint |
| age | home | age, age-inspect, age-keygen, age-plugin-batchpass |
| ansifilter | common, home, work | ansifilter |
| aoe | common, home, work | aoe |
| ast-grep | common, home, work | ast-grep, sg |
| bandwhich | common, home, work | bandwhich |
| bash | common, home, work | bash, bashbug |
| bat | common, home, work | bat |
| bats-core | common, home, work | bats |
| bc | home | bc, dc |
| bottom | common, home, work | btm |
| boxes | common, home, work | boxes |
| broot | common, home, work | broot |
| chafa | common, home, work | chafa |
| chromaprint | home | fpcalc |
| coreutils | common, home, work | b2sum, base32, basenc, factor, g[, gb2sum, gbase32, gbase64, gbasename, gbasenc, gcat, gchgrp, gchmod, gchown, gchroot, gcksum, gcomm, gcp, gcsplit, gcut, gdate, gdd, gdf, gdir, gdircolors, gdirname, gdu, gecho, genv, gexpand, gexpr, gfactor, gfalse, gfmt, gfold, ggroups, ghead, ghostid, gid, ginstall, gjoin, glink, gln, glogname, gls, gmd5sum, gmkdir, gmkfifo, gmknod, gmktemp, gmv, gnice, gnl, gnohup, gnproc, gnumfmt, god, gpaste, gpathchk, gpinky, gpr, gprintenv, gprintf, gptx, gpwd, greadlink, grealpath, grm, grmdir, gseq, gsha1sum, gsha224sum, gsha256sum, gsha384sum, gsha512sum, gshred, gshuf, gsleep, gsort, gsplit, gstat, gstdbuf, gstty, gsum, gsync, gtac, gtail, gtee, gtest, gtimeout, gtouch, gtr, gtrue, gtruncate, gtsort, gtty, guname, gunexpand, guniq, gunlink, gusers, gvdir, gwc, gwho, gwhoami, gyes, hostid, nproc, numfmt, pinky, ptx, shred, shuf, tac, timeout |
| csvlens | common, home, work | csvlens |
| dasel | common, home, work | dasel |
| dash-shell | home | dash |
| dashing | common, home, work | dashing |
| diff-so-fancy | common, home, work | diff-so-fancy |
| difftastic | common, home, work | difft |
| direnv | common, home, work | direnv |
| docker-buildx | common, home, work | docker-buildx |
| docker-clean | home | docker-clean |
| docker-compose | common, home, work | docker-compose |
| docker-compose-langserver | common, home, work | docker-compose-langserver |
| docker-credential-helper | common, home, work | docker-credential-osxkeychain, docker-credential-pass |
| duckdb | common, home, work | duckdb, duckdb_cli |
| entr | common, home, work | entr |
| eza | common, home, work | eza |
| fabric-ai | common, home, work | fabric-ai |
| fd | common, home, work | fd |
| fdupes | common, home, work | fdupes |
| ffmpeg | common, home, work | aviocat, bisect-create, check_arm_indent.sh, check_commit_msg.sh, clean-diff, compare-cvelists.sh, crypto_bench, cws2fws, dvd2concat, enc_recon_frame_test, enum_options, ffescape, ffeval, ffhash, ffmpeg, ffplay, ffprobe, fourcc2pixfmt, gen-rc, general_assembly.pl, graph2dot, indent_arm_assembly.pl, ismindex, loudnorm.rb, make_chlayout_test, merge-all-source-plugins, missing_codec_desc, murge, normalize.py, patcheck, pktdumper, plotframes, probetest, qt-faststart, scale_slice_test, seek_print, sidxindex, source2c, target_dec_fate.sh, trasher, uncoded_frame, unwrap-diff, update-checkasm.sh, venc_data_dump, zmqshell.py |
| fish | common, home, work | fish, fish_indent, fish_key_reader |
| flyctl | home | fly, flyctl |
| fprobe | home | fprobe |
| fswatch | common, home, work | fswatch |
| fx | common, home, work | fx |
| fzf | common, home, work | fzf, fzf-preview.sh, fzf-tmux |
| ghostscript | common, home, work | dvipdf, eps2eps, gpcl6, gpcl6c, gpdlc, gs, gsbj, gsc, gsdj, gsdj500, gslj, gslp, gsnd, gsx, gxps, gxpsc, lprsetup.sh, pdf2dsc, pdf2ps, pf2afm, pfbtopfa, pphs, printafm, ps2ascii, ps2epsi, ps2pdf, ps2pdf12, ps2pdf13, ps2pdf14, ps2pdfwr, ps2ps, ps2ps2, unix-lpr.sh |
| git-absorb | common, home, work | git-absorb |
| git-cliff | common, home, work | git-cliff |
| git-delta | common, home, work | delta |
| git-filter-repo | common, home, work | git-filter-repo |
| git-lfs | common, home, work | git-lfs |
| github-keygen | common, home, work | github-keygen |
| gitleaks | common, home, work | gitleaks |
| gitlint | common, home, work | gitlint, python, python3, python3.14, 𝜋thon |
| glow | common, home, work | glow |
| gnu-tar | home | gtar |
| gnupg | common, home, work | addgnupghome, applygnupgdefaults, dirmngr, dirmngr-client, gpg, gpg-agent, gpg-authcode-sign.sh, gpg-card, gpg-connect-agent, gpg-mail-tube, gpg-wks-client, gpg-wks-server, gpgconf, gpgparsemail, gpgscm, gpgsm, gpgsplit, gpgtar, gpgv, kbxutil, watchgnupg |
| go | common, home, work | go, gofmt |
| graphicsmagick | common, home, work | GraphicsMagick++-config, GraphicsMagick-config, GraphicsMagickWand-config, gm |
| graphviz | common, home, work | acyclic, bcomps, ccomps, circo, cluster, dijkstra, dot, dot2gxl, dot_builtins, dot_sandbox, edgepaint, fdp, gc, gml2gv, graphml2gv, gv2gml, gv2gxl, gvcolor, gvgen, gvmap, gvmap.sh, gvpack, gvpr, gxl2dot, gxl2gv, mm2gv, neato, nop, osage, patchwork, prune, sccmap, sfdp, tred, twopi, unflatten |
| grep | common, home, work | gegrep, gfgrep, ggrep |
| hadolint | common, home, work | hadolint |
| herdr | home | herdr |
| html2text | home | html2text |
| hyperfine | common, home, work | hyperfine |
| imagemagick | common, home, work | Magick++-config, MagickCore-config, MagickWand-config, animate, compare, composite, conjure, convert, display, identify, import, magick, magick-script, mogrify, montage, stream |
| jemalloc | common, home, work | jemalloc-config, jemalloc.sh, jeprof |
| jless | common, home, work | jless |
| jq | common, home, work | jq |
| julia | home | julia |
| k6 | common, home, work | k6 |
| k9s | home, work | k9s |
| kcov | home | kcov |
| kubectx | home, work | kubectl-ctx, kubectl-ns, kubectx, kubens |
| kubernetes-cli | home, work | kubectl |
| lazydocker | common, home, work | lazydocker |
| lazygit | common, home, work | lazygit |
| librsvg | common, home, work | rsvg-convert |
| libxml2 | rails-modernization | xml2-config, xmlcatalog, xmllint |
| libxslt | rails-modernization | xslt-config, xsltproc |
| litecli | common, home, work | httpx2, idna, litecli, llm, puremagic, pygmentize, python, python3, python3.14, sqlformat, sqlite-utils, tabulate, ulid, 𝜋thon |
| lnav | common, home, work | lnav |
| luacheck | common, home, work | luacheck |
| luarocks | common, home, work | luarocks, luarocks-admin |
| lynx | home | lynx |
| mactop | common, home, work | mactop |
| memcached | rails-modernization | memcached |
| mercurial | home | chg, hg |
| mermaid-cli | common, home, work | mmdc |
| mkcert | common, home, work | mkcert |
| mkdocs | home | ghp-import, markdown_py, mkdocs, mkdocs-get-deps, python, python3, python3.14, watchmedo, 𝜋thon |
| mmv | common, home, work | mad, mcp, mln, mmv |
| models | home | models |
| ncdu | common, home, work | ncdu |
| ninja | common, home, work | ninja |
| nmap | home | ncat, ndiff, nmap, nping |
| node | common, home, work | node, npm, npx |
| nvtop | common, home, work | nvtop |
| ollama | common, home, work | ollama |
| openapi | common, home, work | openapi |
| openapi-diff | common, home, work | openapi-diff |
| openapi-generator | common, home, work | openapi-generator |
| openapi-tui | common, home, work | openapi-tui |
| openjdk | common, home, work | jar, jarsigner, java, javac, javadoc, javap, jcmd, jconsole, jdb, jdeprscan, jdeps, jfr, jhsdb, jimage, jinfo, jlink, jmap, jmod, jnativescan, jpackage, jps, jshell, jstack, jstat, jstatd, jwebserver, keytool, rmiregistry, serialver |
| openssl@3 | common, home, work | c_rehash, openssl |
| ossp-uuid | common, home, work | uuid, uuid-config |
| otel-cli | common, home, work | otel-cli |
| pandoc | common, home, work | pandoc |
| pdfly | home | fonttools, idna, inv, invoke, markdown-it, normalizer, pdfly, pybidi, pyftmerge, pyftsubset, pygmentize, python, python3, python3.15, ttx, typer |
| pgcli | common, home, work | pgcli, pygmentize, python, python3, python3.14, sqlformat, tabulate, 𝜋thon |
| phalanxduel/tap/duel-cli | home | duel-cli |
| pipx | common, home, work | activate-global-python-argcomplete, pipx, python, python3, python3.15, register-python-argcomplete, userpath |
| pre-commit | common, home, work | identify-cli, nodeenv, pre-commit, python, python3, python3.15, virtualenv |
| prettier | common, home, work | prettier |
| pv | common, home, work | pv |
| python | common, home, work | idle, idle3, idle3.15, pip, pip3, pip3.15, pydoc, pydoc3, pydoc3.15, python, python-config, python3, python3-config, python3.15, python3.15-config |
| qt | home | Assistant, Designer, Linguist, androiddeployqt, androiddeployqt6, androidtestrunner, balsam, balsamui, canbusutil, cooker, harmonydeployqt, harmonydeployqt6, harmonyostestrunner, instancer, lcheck, lconvert, lightmapviewer, lottietoqml, lrelease, lrelease-pro, ltext2id, lupdate, lupdate-pro, macdeployqt, macdeployqt6, materialeditor, meshdebug, particleshadergen, pixeltool, qcshadergen, qdbus, qdbuscpp2xml, qdbusviewer, qdbusxml2cpp, qdistancefieldgenerator, qmake, qmake6, qml, qmlcontextpropertydump, qmldom, qmleasing, qmlformat, qmllint, qmlls, qmlplugindump, qmlpreview, qmlprofiler, qmlscene, qmltc, qmltestrunner, qmltime, qqem, qsb, qt-cmake, qt-cmake-create, qt-configure-module, qtdiag, qtdiag6, qtpaths, qtpaths6, qtplugininfo, shadergen, shapegen, svgtoqml, wasmdeployqt, wasmdeployqt6 |
| rename | common, home, work | rename |
| repomix | common, home, work | repomix |
| restic | home | restic |
| ripgrep | common, home, work | rg |
| roblox-ts | home | rbxtsc |
| rsync | common, home, work | rrsync, rsync, rsync-ssl |
| rubberband | common, home, work | rubberband, rubberband-r3 |
| ruby-lsp | common, home, work | minitest, rbs, ruby-lsp, ruby-lsp-check, ruby-lsp-launcher, ruby-lsp-test-exec, test-unit |
| rustup | common, home, work | cargo, cargo-clippy, cargo-fmt, cargo-miri, clippy-driver, rls, rust-analyzer, rust-gdb, rust-gdbgui, rust-lldb, rustc, rustdoc, rustfmt, rustup |
| sd | common, home, work | sd |
| selene | common, home, work | selene |
| sentry-cli | common, home, work | sentry-cli |
| sesh | common, home, work | sesh |
| shared-mime-info | rails-modernization | update-mime-database |
| shellcheck | common, home, work | shellcheck |
| shfmt | common, home, work | shfmt |
| sponge | common, home, work | sponge |
| sqlite | common, home, work | sqlite3 |
| sqlite-utils | common, home, work | python, python3, python3.14, sqlite-utils, tabulate, 𝜋thon |
| ssh-copy-id | common, home, work | ssh-copy-id |
| stylua | common, home, work | stylua |
| svgo | common, home, work | svgo |
| swift-format | common, home, work | swift-format |
| swiftformat | common, home, work | swiftformat |
| swiftlint | common, home, work | swiftlint |
| syft | common, home, work | syft |
| taplo | common, home, work | taplo |
| tealdeer | common, home, work | tldr |
| tectonic | common, home, work | nextonic, tectonic |
| television | common, home, work | tv |
| terminal-notifier | common, home, work | terminal-notifier |
| tokei | common, home, work | tokei |
| tree-sitter-cli | common, home, work | tree-sitter |
| trivy | common, home, work | trivy |
| trufflehog | common, home, work | trufflehog |
| universal-ctags | common, home, work | ctags, optscript, readtags |
| usage | common, home, work | usage |
| uv | common, home, work | uv, uvx |
| vale | home | vale |
| vips | common, home, work | vips, vipsedit, vipsheader, vipsthumbnail |
| visidata | common, home, work | python, python3, python3.15, vd, vd2to3.vdx, vdx, visidata |
| vivid | common, home, work | vivid |
| watch | common, home, work | watch |
| watchexec | common, home, work | watchexec |
| wget | common, home, work | wget |
| whisper-cpp | common, home, work | parakeet-cli, parakeet-quantize, whisper-bench, whisper-cli, whisper-command, whisper-lsp, whisper-quantize, whisper-server, whisper-stream, whisper-talk-llama, whisper-vad-speech-segments |
| whisperkit-cli | common, home, work | whisperkit-cli |
| xcodegen | common, home, work | xcodegen |
| xmlstarlet | common, home, work | xml, xmlstarlet |
| yamllint | common, home, work | python, python3, python3.14, yamllint, 𝜋thon |
| yarn | common, home, work | yarn, yarn.cmd, yarn.js, yarnpkg, yarnpkg.cmd |
| yq | common, home, work | yq |
| yt-dlp | common, home, work | curl-cffi, idna, mid3cp, mid3iconv, mid3v2, moggsplit, mutagen-inspect, mutagen-pony, normalizer, python, python3, python3.15, websockets, yt-dlp |
| zoxide | common, home, work | zoxide |
| zsh | common, home, work | zsh, zsh-5.9.2 |
| zsh-history-enquirer | common, home, work | zsh-history-enquirer |

Review each candidate against repo workflows, Nginx routes, service state, aliases, and related platform repositories before any removal.

## Declared but not installed

| Formula | Profile(s) |
| --- | --- |
| aws-vault | work |
| awscli | work |
| cfn-lint | work |
| checkov | work |
| eksctl | work |
| granted | work |
| helm | work |
| kustomize | work |
| mariadb-connector-c | rails-modernization |
| mongodb-database-tools | rails-modernization |
| mysql-client | work |
| stern | work |
| terraform | work |

## Installed formula mapping

| Formula spec | Profile(s) | Provided executables | Direct calls | Service state |
| --- | --- | --- | --- | --- |
| ack | common, home, work | ack | 84 |  |
| act | common, home, work | act | 5 |  |
| actionlint | common, home, work | actionlint | 0 |  |
| age | home | age, age-inspect, age-keygen, age-plugin-batchpass | 0 |  |
| aider | common, home, work | aider, distro, dotenv, f2py, fastapi, flake8, gast, grep-ast, hf, httpx, jsonschema, litellm, litellm-proxy, markdown-it, mslex-split, normalizer, openai, playwright, pycodestyle, pyflakes, pygmentize, pyjson5, python, python3, python3.12, shtab, tiny-agents, tqdm, typer, watchfiles | 0 | operational: used through the `zaider` / `laid` shell wrappers |
| ansifilter | common, home, work | ansifilter | 0 |  |
| aoe | common, home, work | aoe | 0 |  |
| apfel | home | apfel | 0 | brew service: started |
| ast-grep | common, home, work | ast-grep, sg | 0 |  |
| atuin | common, home, work | atuin | 1 | brew service: started |
| backlog-md | common, home, work | backlog | 1 |  |
| bandwhich | common, home, work | bandwhich | 0 |  |
| bash | common, home, work | bash, bashbug | 0 |  |
| bat | common, home, work | bat | 0 |  |
| bats-core | common, home, work | bats | 0 |  |
| bc | home | bc, dc | 0 |  |
| bottom | common, home, work | btm | 0 |  |
| boxes | common, home, work | boxes | 0 |  |
| broot | common, home, work | broot | 0 |  |
| btop | common, home, work | btop | 7 |  |
| chafa | common, home, work | chafa | 0 |  |
| chromaprint | home | fpcalc | 0 |  |
| cmake | common, home, work | ccmake, cmake, cpack, ctest | 3 |  |
| colima | common, home, work | colima | 11 | operational: CLI retained for on-demand Docker use; VM removed and login autostart disabled under the bare-metal local-work rule |
| coreutils | common, home, work | b2sum, base32, basenc, factor, g[, gb2sum, gbase32, gbase64, gbasename, gbasenc, gcat, gchgrp, gchmod, gchown, gchroot, gcksum, gcomm, gcp, gcsplit, gcut, gdate, gdd, gdf, gdir, gdircolors, gdirname, gdu, gecho, genv, gexpand, gexpr, gfactor, gfalse, gfmt, gfold, ggroups, ghead, ghostid, gid, ginstall, gjoin, glink, gln, glogname, gls, gmd5sum, gmkdir, gmkfifo, gmknod, gmktemp, gmv, gnice, gnl, gnohup, gnproc, gnumfmt, god, gpaste, gpathchk, gpinky, gpr, gprintenv, gprintf, gptx, gpwd, greadlink, grealpath, grm, grmdir, gseq, gsha1sum, gsha224sum, gsha256sum, gsha384sum, gsha512sum, gshred, gshuf, gsleep, gsort, gsplit, gstat, gstdbuf, gstty, gsum, gsync, gtac, gtail, gtee, gtest, gtimeout, gtouch, gtr, gtrue, gtruncate, gtsort, gtty, guname, gunexpand, guniq, gunlink, gusers, gvdir, gwc, gwho, gwhoami, gyes, hostid, nproc, numfmt, pinky, ptx, shred, shuf, tac, timeout | 0 |  |
| cpp-httplib | home | (no executable in bin/sbin/libexec/bin) | — | no CLI binary |
| csvlens | common, home, work | csvlens | 0 |  |
| curl | common, home, work | curl, curl-config, wcurl | 6 |  |
| dasel | common, home, work | dasel | 0 |  |
| dash-shell | home | dash | 0 |  |
| dashing | common, home, work | dashing | 0 |  |
| diff-so-fancy | common, home, work | diff-so-fancy | 0 |  |
| difftastic | common, home, work | difft | 0 |  |
| direnv | common, home, work | direnv | 0 |  |
| docker | common, home, work | docker | 1 |  |
| docker-buildx | common, home, work | docker-buildx | 0 |  |
| docker-clean | home | docker-clean | 0 |  |
| docker-compose | common, home, work | docker-compose | 0 |  |
| docker-compose-langserver | common, home, work | docker-compose-langserver | 0 |  |
| docker-credential-helper | common, home, work | docker-credential-osxkeychain, docker-credential-pass | 0 |  |
| duckdb | common, home, work | duckdb, duckdb_cli | 0 |  |
| dust | common, home, work | dust | 3 |  |
| entr | common, home, work | entr | 0 |  |
| eza | common, home, work | eza | 0 |  |
| fabric-ai | common, home, work | fabric-ai | 0 |  |
| fd | common, home, work | fd | 0 |  |
| fdupes | common, home, work | fdupes | 0 |  |
| ffmpeg | common, home, work | aviocat, bisect-create, check_arm_indent.sh, check_commit_msg.sh, clean-diff, compare-cvelists.sh, crypto_bench, cws2fws, dvd2concat, enc_recon_frame_test, enum_options, ffescape, ffeval, ffhash, ffmpeg, ffplay, ffprobe, fourcc2pixfmt, gen-rc, general_assembly.pl, graph2dot, indent_arm_assembly.pl, ismindex, loudnorm.rb, make_chlayout_test, merge-all-source-plugins, missing_codec_desc, murge, normalize.py, patcheck, pktdumper, plotframes, probetest, qt-faststart, scale_slice_test, seek_print, sidxindex, source2c, target_dec_fate.sh, trasher, uncoded_frame, unwrap-diff, update-checkasm.sh, venc_data_dump, zmqshell.py | 0 |  |
| fish | common, home, work | fish, fish_indent, fish_key_reader | 0 |  |
| flyctl | home | fly, flyctl | 0 |  |
| fprobe | home | fprobe | 0 |  |
| fswatch | common, home, work | fswatch | 0 |  |
| fx | common, home, work | fx | 0 |  |
| fzf | common, home, work | fzf, fzf-preview.sh, fzf-tmux | 0 |  |
| fzf-tab | common, home, work | (no executable in bin/sbin/libexec/bin) | — | no CLI binary |
| geoipupdate | common, home, work | geoipupdate | 6 |  |
| gh | common, home, work | gh | 9 |  |
| ghostscript | common, home, work | dvipdf, eps2eps, gpcl6, gpcl6c, gpdlc, gs, gsbj, gsc, gsdj, gsdj500, gslj, gslp, gsnd, gsx, gxps, gxpsc, lprsetup.sh, pdf2dsc, pdf2ps, pf2afm, pfbtopfa, pphs, printafm, ps2ascii, ps2epsi, ps2pdf, ps2pdf12, ps2pdf13, ps2pdf14, ps2pdfwr, ps2ps, ps2ps2, unix-lpr.sh | 0 |  |
| git | common, home, work | git, git-cvsserver, git-receive-pack, git-shell, git-upload-archive, git-upload-pack, scalar | 67 |  |
| git-absorb | common, home, work | git-absorb | 0 |  |
| git-cliff | common, home, work | git-cliff | 0 |  |
| git-delta | common, home, work | delta | 0 |  |
| git-filter-repo | common, home, work | git-filter-repo | 0 |  |
| git-lfs | common, home, work | git-lfs | 0 |  |
| github-keygen | common, home, work | github-keygen | 0 |  |
| gitleaks | common, home, work | gitleaks | 0 |  |
| gitlint | common, home, work | gitlint, python, python3, python3.14, 𝜋thon | 0 |  |
| glow | common, home, work | glow | 0 |  |
| gnu-tar | home | gtar | 0 |  |
| gnupg | common, home, work | addgnupghome, applygnupgdefaults, dirmngr, dirmngr-client, gpg, gpg-agent, gpg-authcode-sign.sh, gpg-card, gpg-connect-agent, gpg-mail-tube, gpg-wks-client, gpg-wks-server, gpgconf, gpgparsemail, gpgscm, gpgsm, gpgsplit, gpgtar, gpgv, kbxutil, watchgnupg | 0 |  |
| go | common, home, work | go, gofmt | 0 |  |
| gource | home | gource | 4 |  |
| graphicsmagick | common, home, work | GraphicsMagick++-config, GraphicsMagick-config, GraphicsMagickWand-config, gm | 0 |  |
| graphviz | common, home, work | acyclic, bcomps, ccomps, circo, cluster, dijkstra, dot, dot2gxl, dot_builtins, dot_sandbox, edgepaint, fdp, gc, gml2gv, graphml2gv, gv2gml, gv2gxl, gvcolor, gvgen, gvmap, gvmap.sh, gvpack, gvpr, gxl2dot, gxl2gv, mm2gv, neato, nop, osage, patchwork, prune, sccmap, sfdp, tred, twopi, unflatten | 0 |  |
| grep | common, home, work | gegrep, gfgrep, ggrep | 0 |  |
| hadolint | common, home, work | hadolint | 0 |  |
| herdr | home | herdr | 0 |  |
| hister | home | hister | 0 | brew service: started |
| html2text | home | html2text | 0 |  |
| htop | common, home, work | htop | 2 |  |
| hyperfine | common, home, work | hyperfine | 0 |  |
| imagemagick | common, home, work | Magick++-config, MagickCore-config, MagickWand-config, animate, compare, composite, conjure, convert, display, identify, import, magick, magick-script, mogrify, montage, stream | 0 |  |
| jemalloc | common, home, work | jemalloc-config, jemalloc.sh, jeprof | 0 |  |
| jless | common, home, work | jless | 0 |  |
| jq | common, home, work | jq | 0 |  |
| julia | home | julia | 0 |  |
| k6 | common, home, work | k6 | 0 |  |
| k9s | home, work | k9s | 0 |  |
| kcov | home | kcov | 0 |  |
| kubectx | home, work | kubectl-ctx, kubectl-ns, kubectx, kubens | 0 |  |
| kubernetes-cli | home, work | kubectl | 0 |  |
| lazydocker | common, home, work | lazydocker | 0 |  |
| lazygit | common, home, work | lazygit | 0 |  |
| librsvg | common, home, work | rsvg-convert | 0 |  |
| libxml2 | rails-modernization | xml2-config, xmlcatalog, xmllint | 0 |  |
| libxslt | rails-modernization | xslt-config, xsltproc | 0 |  |
| litecli | common, home, work | httpx2, idna, litecli, llm, puremagic, pygmentize, python, python3, python3.14, sqlformat, sqlite-utils, tabulate, ulid, 𝜋thon | 0 |  |
| llama.cpp | common, home, work | ggml-metal-tuning, llama, llama-batched, llama-batched-bench, llama-bench, llama-cli, llama-completion, llama-debug, llama-diffusion-cli, llama-embedding, llama-eval-callback, llama-finetune, llama-fit-params, llama-gen-docs, llama-gguf, llama-gguf-hash, llama-gguf-split, llama-idle, llama-imatrix, llama-lookahead, llama-lookup, llama-lookup-create, llama-lookup-merge, llama-lookup-stats, llama-mtmd-cli, llama-parallel, llama-passkey, llama-perplexity, llama-quantize, llama-results, llama-retrieval, llama-server, llama-simple, llama-simple-chat, llama-speculative, llama-speculative-simple, llama-tokenize, llama-tts | 0 | operational: backs the active Qwen3-8B service and core AI query routes |
| lnav | common, home, work | lnav | 0 |  |
| luacheck | common, home, work | luacheck | 0 |  |
| luarocks | common, home, work | luarocks, luarocks-admin | 0 |  |
| lynx | home | lynx | 0 |  |
| mactop | common, home, work | mactop | 0 |  |
| memcached | rails-modernization | memcached | 0 |  |
| mercurial | home | chg, hg | 0 |  |
| mermaid-cli | common, home, work | mmdc | 0 |  |
| mise | common, home, work | mise | 1 |  |
| mkcert | common, home, work | mkcert | 0 |  |
| mkdocs | home | ghp-import, markdown_py, mkdocs, mkdocs-get-deps, python, python3, python3.14, watchmedo, 𝜋thon | 0 |  |
| mmv | common, home, work | mad, mcp, mln, mmv | 0 |  |
| models | home | models | 0 |  |
| ncdu | common, home, work | ncdu | 0 |  |
| neovim | common, home, work | nvim | 1 |  |
| nginx | common, home, work | nginx | 2 | operational: root-managed reverse proxy for core and related-repo services; restart requires operator sudo |
| ninja | common, home, work | ninja | 0 |  |
| nmap | home | ncat, ndiff, nmap, nping | 0 |  |
| node | common, home, work | node, npm, npx | 0 |  |
| nvtop | common, home, work | nvtop | 0 |  |
| ollama | common, home, work | ollama | 0 |  |
| openapi | common, home, work | openapi | 0 |  |
| openapi-diff | common, home, work | openapi-diff | 0 |  |
| openapi-generator | common, home, work | openapi-generator | 0 |  |
| openapi-tui | common, home, work | openapi-tui | 0 |  |
| opencode | common, home, work | opencode | 0 | operational: exposed through the `zopencode` shell wrapper |
| openjdk | common, home, work | jar, jarsigner, java, javac, javadoc, javap, jcmd, jconsole, jdb, jdeprscan, jdeps, jfr, jhsdb, jimage, jinfo, jlink, jmap, jmod, jnativescan, jpackage, jps, jshell, jstack, jstat, jstatd, jwebserver, keytool, rmiregistry, serialver | 0 |  |
| openssl@3 | common, home, work | c_rehash, openssl | 0 |  |
| ossp-uuid | common, home, work | uuid, uuid-config | 0 |  |
| otel-cli | common, home, work | otel-cli | 0 |  |
| pandoc | common, home, work | pandoc | 0 |  |
| pdfly | home | fonttools, idna, inv, invoke, markdown-it, normalizer, pdfly, pybidi, pyftmerge, pyftsubset, pygmentize, python, python3, python3.15, ttx, typer | 0 |  |
| pgcli | common, home, work | pgcli, pygmentize, python, python3, python3.14, sqlformat, tabulate, 𝜋thon | 0 |  |
| pgvector | common, home, work | (no executable in bin/sbin/libexec/bin) | — | no CLI binary |
| phalanxduel/tap/duel-cli | home | duel-cli | 0 |  |
| pipx | common, home, work | activate-global-python-argcomplete, pipx, python, python3, python3.15, register-python-argcomplete, userpath | 0 |  |
| pnpm | common, home, work | pn, pnpm, pnpx, pnx | 11 |  |
| postgresql@18 | common, home, work | clusterdb, createdb, createuser, dropdb, dropuser, ecpg, initdb, oid2name, pg_amcheck, pg_archivecleanup, pg_basebackup, pg_checksums, pg_combinebackup, pg_config, pg_controldata, pg_createsubscriber, pg_ctl, pg_dump, pg_dumpall, pg_isready, pg_receivewal, pg_recvlogical, pg_resetwal, pg_restore, pg_rewind, pg_test_fsync, pg_test_timing, pg_upgrade, pg_verifybackup, pg_waldump, pg_walsummary, pgbench, postgres, psql, reindexdb, vacuumdb, vacuumlo | 0 | brew service: started |
| powerlevel10k | common, home, work | (no executable in bin/sbin/libexec/bin) | — | no CLI binary |
| pre-commit | common, home, work | identify-cli, nodeenv, pre-commit, python, python3, python3.15, virtualenv | 0 |  |
| prettier | common, home, work | prettier | 0 |  |
| pv | common, home, work | pv | 0 |  |
| python | common, home, work | idle, idle3, idle3.15, pip, pip3, pip3.15, pydoc, pydoc3, pydoc3.15, python, python-config, python3, python3-config, python3.15, python3.15-config | 0 |  |
| qt | home | Assistant, Designer, Linguist, androiddeployqt, androiddeployqt6, androidtestrunner, balsam, balsamui, canbusutil, cooker, harmonydeployqt, harmonydeployqt6, harmonyostestrunner, instancer, lcheck, lconvert, lightmapviewer, lottietoqml, lrelease, lrelease-pro, ltext2id, lupdate, lupdate-pro, macdeployqt, macdeployqt6, materialeditor, meshdebug, particleshadergen, pixeltool, qcshadergen, qdbus, qdbuscpp2xml, qdbusviewer, qdbusxml2cpp, qdistancefieldgenerator, qmake, qmake6, qml, qmlcontextpropertydump, qmldom, qmleasing, qmlformat, qmllint, qmlls, qmlplugindump, qmlpreview, qmlprofiler, qmlscene, qmltc, qmltestrunner, qmltime, qqem, qsb, qt-cmake, qt-cmake-create, qt-configure-module, qtdiag, qtdiag6, qtpaths, qtpaths6, qtplugininfo, shadergen, shapegen, svgtoqml, wasmdeployqt, wasmdeployqt6 | 0 |  |
| ranger | common, home, work | python, python3, python3.14, ranger, rifle, 𝜋thon | 1 |  |
| redis | common, home, work | redis-benchmark, redis-check-aof, redis-check-rdb, redis-cli, redis-sentinel, redis-server | 0 | brew service: started |
| rename | common, home, work | rename | 0 |  |
| repomix | common, home, work | repomix | 0 |  |
| restic | home | restic | 0 |  |
| ripgrep | common, home, work | rg | 0 |  |
| roblox-ts | home | rbxtsc | 0 |  |
| rsync | common, home, work | rrsync, rsync, rsync-ssl | 0 |  |
| rtk | common, home, work | rtk | 4 |  |
| rubberband | common, home, work | rubberband, rubberband-r3 | 0 |  |
| ruby-lsp | common, home, work | minitest, rbs, ruby-lsp, ruby-lsp-check, ruby-lsp-launcher, ruby-lsp-test-exec, test-unit | 0 |  |
| rustup | common, home, work | cargo, cargo-clippy, cargo-fmt, cargo-miri, clippy-driver, rls, rust-analyzer, rust-gdb, rust-gdbgui, rust-lldb, rustc, rustdoc, rustfmt, rustup | 0 |  |
| sd | common, home, work | sd | 0 |  |
| selene | common, home, work | selene | 0 |  |
| sentry-cli | common, home, work | sentry-cli | 0 |  |
| sesh | common, home, work | sesh | 0 |  |
| shared-mime-info | rails-modernization | update-mime-database | 0 |  |
| shellcheck | common, home, work | shellcheck | 0 |  |
| shfmt | common, home, work | shfmt | 0 |  |
| sponge | common, home, work | sponge | 0 |  |
| sqlite | common, home, work | sqlite3 | 0 |  |
| sqlite-utils | common, home, work | python, python3, python3.14, sqlite-utils, tabulate, 𝜋thon | 0 |  |
| ssh-copy-id | common, home, work | ssh-copy-id | 0 |  |
| stylua | common, home, work | stylua | 0 |  |
| svgo | common, home, work | svgo | 0 |  |
| swift-format | common, home, work | swift-format | 0 |  |
| swiftformat | common, home, work | swiftformat | 0 |  |
| swiftlint | common, home, work | swiftlint | 0 |  |
| syft | common, home, work | syft | 0 |  |
| syncthing | home | syncthing | 0 | brew service: started |
| taplo | common, home, work | taplo | 0 |  |
| tealdeer | common, home, work | tldr | 0 |  |
| tectonic | common, home, work | nextonic, tectonic | 0 |  |
| television | common, home, work | tv | 0 |  |
| terminal-notifier | common, home, work | terminal-notifier | 0 |  |
| tmux | common, home, work | tmux | 3 |  |
| tokei | common, home, work | tokei | 0 |  |
| tomlplusplus | home | (no executable in bin/sbin/libexec/bin) | — | no CLI binary |
| tree | common, home, work | tree | 15 |  |
| tree-sitter | common, home, work | (no executable in bin/sbin/libexec/bin) | — | no CLI binary |
| tree-sitter-cli | common, home, work | tree-sitter | 0 |  |
| tree-sitter-go | home | (no executable in bin/sbin/libexec/bin) | — | no CLI binary |
| tree-sitter-python | home | (no executable in bin/sbin/libexec/bin) | — | no CLI binary |
| tree-sitter-ruby | home | (no executable in bin/sbin/libexec/bin) | — | no CLI binary |
| trivy | common, home, work | trivy | 0 |  |
| trufflehog | common, home, work | trufflehog | 0 |  |
| universal-ctags | common, home, work | ctags, optscript, readtags | 0 |  |
| usage | common, home, work | usage | 0 |  |
| uv | common, home, work | uv, uvx | 0 |  |
| vale | home | vale | 0 |  |
| vips | common, home, work | vips, vipsedit, vipsheader, vipsthumbnail | 0 |  |
| visidata | common, home, work | python, python3, python3.15, vd, vd2to3.vdx, vdx, visidata | 0 |  |
| vivid | common, home, work | vivid | 0 |  |
| watch | common, home, work | watch | 0 |  |
| watchexec | common, home, work | watchexec | 0 |  |
| wget | common, home, work | wget | 0 |  |
| whisper-cpp | common, home, work | parakeet-cli, parakeet-quantize, whisper-bench, whisper-cli, whisper-command, whisper-lsp, whisper-quantize, whisper-server, whisper-stream, whisper-talk-llama, whisper-vad-speech-segments | 0 |  |
| whisperkit-cli | common, home, work | whisperkit-cli | 0 |  |
| xcodegen | common, home, work | xcodegen | 0 |  |
| xmlstarlet | common, home, work | xml, xmlstarlet | 0 |  |
| yamllint | common, home, work | python, python3, python3.14, yamllint, 𝜋thon | 0 |  |
| yarn | common, home, work | yarn, yarn.cmd, yarn.js, yarnpkg, yarnpkg.cmd | 0 |  |
| yq | common, home, work | yq | 0 |  |
| yt-dlp | common, home, work | curl-cffi, idna, mid3cp, mid3iconv, mid3v2, moggsplit, mutagen-inspect, mutagen-pony, normalizer, python, python3, python3.15, websockets, yt-dlp | 0 |  |
| zoxide | common, home, work | zoxide | 0 |  |
| zsh | common, home, work | zsh, zsh-5.9.2 | 0 |  |
| zsh-autopair | common, home, work | (no executable in bin/sbin/libexec/bin) | — | no CLI binary |
| zsh-autosuggestions | common, home, work | (no executable in bin/sbin/libexec/bin) | — | no CLI binary |
| zsh-completions | common, home, work | (no executable in bin/sbin/libexec/bin) | — | no CLI binary |
| zsh-history-enquirer | common, home, work | zsh-history-enquirer | 0 |  |
| zsh-history-substring-search | common, home, work | (no executable in bin/sbin/libexec/bin) | — | no CLI binary |
| zsh-syntax-highlighting | common, home, work | (no executable in bin/sbin/libexec/bin) | — | no CLI binary |
| zsh-vi-mode | common, home, work | (no executable in bin/sbin/libexec/bin) | — | no CLI binary |
| zsh-you-should-use | common, home, work | (no executable in bin/sbin/libexec/bin) | — | no CLI binary |

## Installed packages without CLI executables

| Formula | Profile(s) | Classification |
| --- | --- | --- |
| cpp-httplib | home | library/data/service package |
| fzf-tab | common, home, work | library/data/service package |
| pgvector | common, home, work | library/data/service package |
| powerlevel10k | common, home, work | library/data/service package |
| tomlplusplus | home | library/data/service package |
| tree-sitter | common, home, work | library/data/service package |
| tree-sitter-go | home | library/data/service package |
| tree-sitter-python | home | library/data/service package |
| tree-sitter-ruby | home | library/data/service package |
| zsh-autopair | common, home, work | library/data/service package |
| zsh-autosuggestions | common, home, work | library/data/service package |
| zsh-completions | common, home, work | library/data/service package |
| zsh-history-substring-search | common, home, work | library/data/service package |
| zsh-syntax-highlighting | common, home, work | library/data/service package |
| zsh-vi-mode | common, home, work | library/data/service package |
| zsh-you-should-use | common, home, work | library/data/service package |

## Profile scope

The work profile intentionally includes corporate VPN, AWS, and EKS tooling. Its missing packages on the home host are not installation recommendations. The Rails modernization Brewfile is optional and explicitly limited to legacy analysis; an unsatisfied optional dependency is not a home-profile defect.
