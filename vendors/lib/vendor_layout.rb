# The page every fake vendor shares: the sandbox banner, the vendor's own brand, tabs, controls and the other vendors.
module VendorLayout
  STYLE = File.read(File.join(__dir__, "vendor_layout.css"))

  FONTS = "family=Space+Grotesk:wght@400;500;700&family=Archivo:wght@400;500;700&family=Archivo+Black&family=Sora:wght@400;600;700&family=IBM+Plex+Mono:wght@400;600"

  # Each vendor has a made-up brand. The wordmark is markup, and its colours and typeface live in vendor_layout.css
  # under the class "v-<key>".
  BRANDS = {
    storebox: { name: "StoreBox", wordmark: "<i class='mk'></i>StoreBox" },
    quickpost: { name: "QuickPost", wordmark: "Quick<b>Post</b>" },
    parceldock: { name: "ParcelDock", wordmark: "<i class='mk'></i>ParcelDock" },
    index: { name: "Sandbox vendors", wordmark: "Sandbox vendors" }
  }.freeze

  module_function

  def h(value) = Rack::Utils.escape_html(value.to_s)

  def wordmark(key, href: nil)
    content = BRANDS.fetch(key)[:wordmark]
    href ? "<a class='mark m-#{key}' href='#{h(href)}'>#{content}</a>" : "<span class='mark m-#{key}'>#{content}</span>"
  end

  # tabs: [[label, href, current?]]. controls and body are trusted HTML. root is the URL prefix the vendors are mounted under.
  def render(vendor:, title:, body:, tabs: [], controls: "", root: "")
    brand = BRANDS.fetch(vendor)
    tab_links = tabs.map { |label, href, current| "<a href='#{h(href)}'#{" aria-current='page'" if current}>#{h(label)}</a>" }.join
    others = (BRANDS.keys - [vendor, :index]).map { |key| wordmark(key, href: "#{root}/#{key}/console") }.join
    <<~HTML
      <!doctype html>
      <html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
      <title>#{h(brand[:name])} #{h(title)}</title>
      <link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
      <link rel="stylesheet" href="https://fonts.googleapis.com/css2?#{FONTS}&display=swap">
      <style>#{STYLE}</style></head>
      <body class="v-#{vendor}">
      <div class="tape"><span>Sandbox, simulated vendor</span></div>
      <header class="top">#{wordmark(vendor)}<nav>#{tab_links}</nav></header>
      <main>
        <div class="head"><h1>#{h(title)}</h1><div class="controls">#{controls}</div></div>
        #{body}
        #{"<footer><span class='label'>Other sandbox vendors</span>#{others}</footer>" unless vendor == :index}
      </main>
      </body></html>
    HTML
  end
end

