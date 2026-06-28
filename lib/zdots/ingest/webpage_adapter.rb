# frozen_string_literal: true

require "net/http"
require "uri"
require "digest"
require "time"
require "nokogiri"
require "reverse_markdown"

module Zdots
  module Ingest
    # Fetch a webpage and return a source_document hash ready for upsert.
    # Strips nav/footer/aside/script/style before converting HTML→Markdown.
    module WebpageAdapter
      MAX_REDIRECTS = 5
      USER_AGENT    = "zdots-ingest/1.0 (+https://github.com/just3ws/zdots)".freeze

      def self.fetch(uri_string)
        fetched_at = Time.now.utc.iso8601
        uri        = URI.parse(uri_string)
        html       = get(uri)
        doc        = Nokogiri::HTML(html)

        title    = doc.at_css("title")&.text&.strip
        doc.search("script, style, nav, footer, aside, header").remove
        body_md  = ReverseMarkdown.convert(doc.at_css("main, article, body").to_s,
                                           unknown_tags: :bypass, github_flavored: true).strip
        checksum = Digest::SHA256.hexdigest(html)

        {
          source_type: "webpage",
          uri:         uri_string,
          title:       title,
          body_md:     body_md,
          checksum:    checksum,
          provenance:  { fetched_at: fetched_at, content_length: html.bytesize },
          fetched_at:  fetched_at
        }
      end

      def self.get(uri, redirects = 0)
        raise "too many redirects" if redirects > MAX_REDIRECTS

        req = Net::HTTP::Get.new(uri)
        req["User-Agent"] = USER_AGENT
        req["Accept"]     = "text/html,application/xhtml+xml"

        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
          http.open_timeout = 10
          http.read_timeout = 20
          res = http.request(req)
          case res
          when Net::HTTPSuccess       then res.body
          when Net::HTTPRedirection   then get(URI.parse(res["location"]), redirects + 1)
          else raise "HTTP #{res.code}: #{uri}"
          end
        end
      end
      private_class_method :get
    end
  end
end
