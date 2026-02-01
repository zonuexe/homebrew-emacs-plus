# frozen_string_literal: true

# UrlHandler builds AppleScript snippets and URL type definitions
# shared between formula (EmacsBase) and cask (CaskEnv).
module UrlHandler
  module_function

  # Build AppleScript handler for emacs://open?url=...&line=&column=
  #
  # escaped_path      - PATH string already escaped for AppleScript shell
  # emacsclient_path  - full path to emacsclient binary
  # enable_handler    - boolean, whether to include emacs:// handler
  #
  # Returns a string containing the AppleScript segment to splice into the app.
  # Returns [needs_framework, handler_body]
  # caller is responsible for adding:
  #   use scripting additions
  #   use framework "Foundation"  (when needs_framework is true)
  def build_applescript(escaped_path:, emacsclient_path:, enable_handler:)
    return [false, ""] unless enable_handler

    handler = <<~APPLESCRIPT
      if this_URL starts with "emacs:" then
        try
          set file_path to ""
          set line_spec to ""
          set AppleScript's text item delimiters to "emacs://open?url="
          set parts to text items of (this_URL as text)
          if (count of parts) > 1 then
            set restURL to item 2 of parts
            set AppleScript's text item delimiters to "&"
            set file_path to item 1 of text items of restURL
            repeat with part in text items of restURL
              set AppleScript's text item delimiters to "="
              set kv to text items of part
              if (count of kv) > 1 then
                set key to item 1 of kv
                set val to item 2 of kv
                if key is "line" then
                  set line_spec to "+" & val
                else if key is "column" then
                  if line_spec is "" then set line_spec to "+"
                  set line_spec to line_spec & ":" & val
                end if
              end if
            end repeat
          end if
          set AppleScript's text item delimiters to ""
          if file_path starts with "file://" then
            set file_path to text 8 thru -1 of file_path
          else if file_path starts with "file:" then
            set file_path to text 6 thru -1 of file_path
          end if
          if file_path is not "" then
            if text 1 of file_path is not "/" then set file_path to "/" & file_path
            if line_spec is not "" then set line_spec to line_spec & " "
            set cmd to "PATH='#{escaped_path}' #{emacsclient_path} -c -a '' -n " & line_spec & quoted form of file_path
            do shell script cmd
            do shell script "open -a Emacs"
            return
          end if
        end try
      end if
    APPLESCRIPT

    [true, handler]
  end

  # Build CFBundleURLTypes array entries (org-protocol always, emacs optional)
  def url_types(enable_handler:)
    types = [
      { name: "Org Protocol", scheme: "org-protocol" },
    ]
    types << { name: "Emacs URL", scheme: "emacs" } if enable_handler
    types
  end
end
