# ==============================================================================
# shady - A Ruby gem to work with Slim, XML, and hashes
#
# Author: Steve Shreeve (steve.shreeve@gmail.com)
#   Date: October 17, 2024
#
#  Legal: MIT license
# ==============================================================================

require "bindings"
require "nokogiri"
require "slim"

# ==[ Monkey patch the Temple gem ]==

=begin

# This requires the following tweak to the 'temple' gem

diff --git a/lib/temple/html/pretty.rb b/lib/temple/html/pretty.rb
index 6143573..29ad071 100644
--- a/lib/temple/html/pretty.rb
+++ b/lib/temple/html/pretty.rb
@@ -10,7 +10,8 @@ module Temple
                                      header hgroup hr html li link meta nav ol option p
                                      rp rt ruby section script style table tbody td tfoot
                                      th thead tr ul video doctype).freeze,
-                     pre_tags: %w(code pre textarea).freeze
+                     pre_tags: %w(code pre textarea).freeze,
+                     strip: false

       def initialize(opts = {})
         super
@@ -62,6 +63,18 @@ module Temple
         result = [:multi, [:static, "#{tag_indent(name)}<#{name}"], compile(attrs)]
         result << [:static, (closed && @format != :html ? ' /' : '') + '>']

+        # strip newlines around terminal nodes
+        @pretty = true
+        case content
+        in [:multi, [:newline]]
+          return (result << [:static, "</#{name}>"])
+        in [:multi, [:multi, [:static, str]]]
+          return (result << [:static, "#{str.strip}</#{name}>"])
+        in [:multi, [:escape, true, [:dynamic, code]], [:multi, [:newline]]]
+          return (result << [:multi, [:escape, true, [:dynamic, code]], [:static, "</#{name}>"]])
+        else nil
+        end if options[:strip]
+
         @pretty = !@pre_tags || !options[:pre_tags].include?(name)
         if content
           @indent += 1
=end

module Temple
  module HTML
    class Pretty
      def on_html_tag(name, attrs, content = nil)
        return super unless @pretty

        name = name.to_s
        closed = !content || (empty_exp?(content) && options[:autoclose].include?(name))

        @pretty = false
        result = [:multi, [:static, "#{tag_indent(name)}<#{name}"], compile(attrs)]
        result << [:static, (closed && @format != :html ? ' /' : '') + '>']

        # strip newlines around terminal nodes
        @pretty = true
        case content
        in [:multi, [:newline]]
          return (result << [:static, "</#{name}>"])
        in [:multi, [:multi, [:static, str]]]
          return (result << [:static, "#{str.strip}</#{name}>"])
        in [:multi, [:escape, true, [:dynamic, code]], [:multi, [:newline]]]
          return (result << [:multi, [:escape, true, [:dynamic, code]], [:static, "</#{name}>"]])
        else nil
        end if options[:strip]

        @pretty = !@pre_tags || !options[:pre_tags].include?(name)
        if content
          @indent += 1
          result << compile(content)
          @indent -= 1
        end
        unless closed
          indent = tag_indent(name)
          result << [:static, "#{content && !empty_exp?(content) ? indent : ''}</#{name}>"]
        end
        @pretty = true
        result
      end
    end
  end
end

# ==[ Extend Nokogiri::XML ]==

module Nokogiri::XML
  class Document
    def to_hash
      root.to_hash
    end
  end

  class Node
    def to_hash(hash={})
      this = {}

      children.each do |c|
        if c.element?
          c.to_hash(this)
        elsif c.text? || c.cdata?
          (this[''] ||= '') << c.content
        end
      end

      text = this.delete('') and text.strip!
      this = text || '' if this.empty? # wtf if !this.empty? && !text.empty?

      case hash[name]
      when nil          then hash[name] = this
      when Hash, String then hash[name] = [hash[name], this]
      when Array        then hash[name] << this
      end

      hash
    end

    def to_slim(deep=0, ns=Set.new)
      slim = "#{'  ' * deep}#{name}"

      # attributes and namespaces
      atts = []
      list = ns.dup
      attributes.map do |name, attr|
        atts << "#{attr.namespace&.prefix&.concat(':')}#{name}=\"#{attr.value}\""
      end
      namespaces.map do |pref, href|
        pair = "#{pref}=\"#{href}\""
        atts << pair if list.add?(pair)
      end
      slim << "(#{atts.join(" ")})" unless atts.empty?

      # terminals and children
      if (kids = element_children).empty? && (info = text&.strip)
        info.empty? ? slim : (slim << " #{info}")
      else
        kids.inject([slim]) {|a, k| a << k.to_slim(deep + 1, list) }.join("\n")
      end
    end
  end
end

# ==[ Extend Slim ]==

module Slim
  class Template
    def result
      binding.of_caller(2).eval(@src)
    end
  end
end

class String
  def slim(scope=nil)
    Slim::Template.new(pretty: true, strip: true, format: :xml) { self }.result
  end

  def xml_to_hash
    Nokogiri.XML(self) {|o| o.default_xml.noblanks}.to_hash rescue {}
  end

  def xml_to_slim
    Nokogiri.XML(self) {|o| o.default_xml.noblanks }.root.to_slim # rescue ""
  end

  def xml_to_xml
    Nokogiri.XML(self) {|o| o.default_xml.noblanks}.to_xml(indent:2) rescue self
  end
end

def slim(str="")
  Slim::Template.new(pretty: true, strip: true, format: :xml) { str }.result
end
