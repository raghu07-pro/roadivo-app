import Foundation

/// Local positive-control form for input delivery, field editing and submission, without third-party site changes.
enum CarBrowserInputFixture {
    static var html: String {
        let heading = escape(String(appLocalized: "Input test"))
        let instruction = escape(String(appLocalized: "Tap the search field, enter text, then submit."))
        let search = escape(String(appLocalized: "Search or enter website"))
        let submit = escape(String(appLocalized: "Submit search"))
        return """
        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
        <style>
        :root{color-scheme:light dark}body{font:22px system-ui;margin:28px;max-width:960px}
        input,button{font:inherit;padding:18px;border:2px solid #888;border-radius:14px}
        input{box-sizing:border-box;width:100%;margin:16px 0}button{cursor:pointer}
        output{display:block;white-space:pre-wrap;margin-top:24px;overflow-wrap:anywhere}
        </style></head><body><h1>\(heading)</h1><p>\(instruction)</p>
        <form role="search" id="probe"><input type="search" name="q" aria-label="\(search)" placeholder="\(search)">
        <button type="submit">\(submit)</button></form><output id="result" aria-live="polite"></output>
        <script>
        document.getElementById('probe').addEventListener('submit',function(event){
          event.preventDefault();document.getElementById('result').textContent=this.elements.q.value;
        });
        </script></body></html>
        """
    }

    private static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }
}
