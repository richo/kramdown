# -*- coding: utf-8 -*-
#
#--
# Copyright (C) 2012 Richo Healey <richo@psych0tik.net>
# Based on work by Thomas Leitner <t_leitner@gmx.at>
#
# This file is part of kramdown.
#
# kramdown is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#++
#

require 'rexml/parsers/baseparser'

module Kramdown

  module Converter

    # Converts a Kramdown::Document to DocBook XML.
    #
    # The return value of such a method has to be a string containing the element +el+ formatted as
    # DocBook XML element
    class Docbook < Base

      begin
        require 'coderay'

        # Highlighting via coderay is available if this constant is +true+.
        HIGHLIGHTING_AVAILABLE = true
      rescue LoadError
        HIGHLIGHTING_AVAILABLE = false  # :nodoc:
      end

      include ::Kramdown::Utils::Html


      # The amount of indentation used when nesting Docbook tags.
      attr_accessor :indent

      # Initialize the Docbook converter with the given Kramdown document +doc+.
      def initialize(root, options)
        super
        @footnote_counter = @footnote_start = @options[:footnote_nr]
        @footnotes = []
        @toc = []
        @toc_code = nil
        @indent = 2
        @stack = []
        @coderay_enabled = @options[:enable_coderay] && HIGHLIGHTING_AVAILABLE
      end

      # The mapping of element type to conversion method.
      DISPATCHER = Hash.new {|h,k| h[k] = "convert_#{k}"}

      # Dispatch the conversion of the element +el+ to a +convert_TYPE+ method using the +type+ of
      # the element.
      def convert(el, indent = -@indent)
        send(DISPATCHER[el.type], el, indent)
      end

      # Return the converted content of the children of +el+ as a string. The parameter +indent+ has
      # to be the amount of indentation used for the element +el+.
      #
      # Pushes +el+ onto the @stack before converting the child elements and pops it from the stack
      # afterwards.
      def inner(el, indent)
        result = ''
        indent += @indent
        @stack.push(el)
        el.children.each do |inner_el|
          result << send(DISPATCHER[inner_el.type], inner_el, indent)
        end
        @stack.pop
        result
      end

      def convert_blank(el, indent)
        "\n"
      end

      def convert_text(el, indent)
        # "<para>#{escape_html(el.value, :text)}</para>"
        "#{escape_html(el.value, :text)}"
      end

      def convert_p(el, indent)
        if el.options[:transparent]
          inner(el, indent)
        else
          "#{' '*indent}<para>#{inner(el, indent)}</para>\n"
        end
      end

      def convert_codeblock(el, indent)
        result = escape_html(el.value)
        result.chomp!
        "#{' '*indent}<programlisting>#{result}\n</programlisting>\n"
      end

      def convert_blockquote(el, indent)
        "#{' '*indent}<blockquote><attribution></attribution><para>#{inner(el, indent)}</para></blockquote>\n"
      end

      def convert_header(el, indent)
        "#{' '*indent}<title>#{inner(el, indent)}</title>\n"
      end

      def convert_hr(el, indent)
        ""
      end

      def convert_ul(el, indent)
        "#{' '*indent}<itemizedlist>\n#{inner(el, indent)}#{' '*indent}</itemizedlist>\n"
      end

      def convert_ol(el, indent)
        "#{' '*indent}<orderelist>\n#{inner(el, indent)}#{' '*indent}</orderedlist>\n"
      end

      def convert_dl(el, indent)
        "#{' '*indent}<variablelist>\n#{inner(el, indent)}#{' '*indent}</variablelist>\n"
      end

      def convert_li(el, indent)
        content = ' '*indent + "<listitem>#{inner(el, indent)}</listitem>"
        # FIXME who knows if this is actually valid
        # if el.parent.type == "dl"
        #   "<varlistentry>#{content}</varlistentry>"
        # else
          content
        # end
      end
      alias :convert_dd :convert_li

      def convert_dt(el, indent)
        "#{' '*indent}<varlistentry><<term>#{inner(el, indent)}</term></varlistentry>\n"
      end

      # # A list of all Docbook tags that need to have a body (even if the body is empty).
      # Docbook_TAGS_WITH_BODY=['div', 'span', 'script', 'iframe', 'textarea', 'a'] # :nodoc:

      def convert_html_element(el, indent)
        res = inner(el, indent)
      #   if el.options[:category] == :span
      #     "<#{el.value}#{html_attributes(el.attr)}" << (!res.empty? || Docbook_TAGS_WITH_BODY.include?(el.value) ? ">#{res}</#{el.value}>" : " />")
      #   else
      #     output = ''
      #     output << ' '*indent if @stack.last.type != :html_element || @stack.last.options[:content_model] != :raw
      #     output << "<#{el.value}#{html_attributes(el.attr)}"
      #     if !res.empty? && el.options[:content_model] != :block
      #       output << ">#{res}</#{el.value}>"
      #     elsif !res.empty?
      #       output << ">\n#{res.chomp}\n"  << ' '*indent << "</#{el.value}>"
      #     elsif Docbook_TAGS_WITH_BODY.include?(el.value)
      #       output << "></#{el.value}>"
      #     else
      #       output << " />"
      #     end
      #     output << "\n" if @stack.last.type != :html_element || @stack.last.options[:content_model] != :raw
      #     output
      #   end
      end

      def convert_xml_comment(el, indent)
        if el.options[:category] == :block && (@stack.last.type != :html_element || @stack.last.options[:content_model] != :raw)
          ' '*indent << el.value << "\n"
        else
          el.value
        end
      end
      alias :convert_xml_pi :convert_xml_comment

      def convert_comment(el, indent)
        if el.options[:category] == :block
          "#{' '*indent}<!-- #{el.value} -->\n"
        else
          "<!-- #{el.value} -->"
        end
      end

      def convert_br(el, indent)
        "<para></para>"
      end

      def convert_a(el, indent)
        "<ulink url=\"#{el.attr['href']}\">#{inner(el, indent)}</ulink>"
      end

      def convert_img(el, indent)
        "<figure><mediaobject><imageobject><imagedata fileref=\"#{el.attr['src']}\"></imagedata></imageobject></mediaobject></figure>"
      end

      def convert_codespan(el, indent)
        "<code>#{escape_html(el.value)}</code>"
      end

      def convert_footnote(el, indent)
        "<footnote><para>#{inner(el, indent)}</para></footnote>"
      end

      def convert_raw(el, indent)
        inner(el, indent)
      end

      def convert_em(el, indent)
        "<emphasis>#{inner(el, indent)}</emphasis>"
      end
      alias :convert_strong :convert_em

      # def convert_entity(el, indent)
      #   entity_to_str(el.value, el.options[:original])
      # end

      TYPOGRAPHIC_SYMS = {
        :mdash => [::Kramdown::Utils::Entities.entity('mdash')],
        :ndash => [::Kramdown::Utils::Entities.entity('ndash')],
        :hellip => [::Kramdown::Utils::Entities.entity('hellip')],
        :laquo_space => [::Kramdown::Utils::Entities.entity('laquo'), ::Kramdown::Utils::Entities.entity('nbsp')],
        :raquo_space => [::Kramdown::Utils::Entities.entity('nbsp'), ::Kramdown::Utils::Entities.entity('raquo')],
        :laquo => [::Kramdown::Utils::Entities.entity('laquo')],
        :raquo => [::Kramdown::Utils::Entities.entity('raquo')]
      } # :nodoc:
      def convert_typographic_sym(el, indent)
        TYPOGRAPHIC_SYMS[el.value].map {|e| entity_to_str(e)}.join('')
      end

      def convert_smart_quote(el, indent)
        # FIXME
        inner(el, indent)
      end

      # def convert_math(el, indent)
      #   block = (el.options[:category] == :block)
      #   value = (el.value =~ /<|&/ ? "% <![CDATA[\n#{el.value} %]]>" : el.value)
      #   "<script type=\"math/tex#{block ? '; mode=display' : ''}\">#{value}</script>#{block ? "\n" : ''}"
      # end

      # def convert_abbreviation(el, indent)
      #   title = @root.options[:abbrev_defs][el.value]
      #   "<abbr#{!title.empty? ? html_attributes(:title => title) : ''}>#{el.value}</abbr>"
      # end

      def convert_root(el, indent)
        result = inner(el, indent)
        # result << footnote_content
        # if @toc_code
        #   toc_tree = generate_toc_tree(@toc, @toc_code[0], @toc_code[1] || {})
        #   text = if toc_tree.children.size > 0
        #            convert(toc_tree, 0)
        #          else
        #            ''
        #          end
        #   result.sub!(/#{@toc_code.last}/, text)
        # end
        result
      end

      # # Generate and return an element tree for the table of contents.
      # def generate_toc_tree(toc, type, attr)
      #   sections = Element.new(type, nil, attr)
      #   sections.attr['id'] ||= 'markdown-toc'
      #   stack = []
      #   toc.each do |level, id, children|
      #     li = Element.new(:li, nil, nil, {:level => level})
      #     li.children << Element.new(:p, nil, nil, {:transparent => true})
      #     a = Element.new(:a, nil, {'href' => "##{id}"})
      #     a.children.concat(remove_footnotes(Marshal.load(Marshal.dump(children))))
      #     li.children.last.children << a
      #     li.children << Element.new(type)

      #     success = false
      #     while !success
      #       if stack.empty?
      #         sections.children << li
      #         stack << li
      #         success = true
      #       elsif stack.last.options[:level] < li.options[:level]
      #         stack.last.children.last.children << li
      #         stack << li
      #         success = true
      #       else
      #         item = stack.pop
      #         item.children.pop unless item.children.last.children.size > 0
      #       end
      #     end
      #   end
      #   while !stack.empty?
      #     item = stack.pop
      #     item.children.pop unless item.children.last.children.size > 0
      #   end
      #   sections
      # end

      # # Remove all footnotes from the given elements.
      # def remove_footnotes(elements)
      #   elements.delete_if do |c|
      #     remove_footnotes(c.children)
      #     c.type == :footnote
      #   end
      # end

      # # Obfuscate the +text+ by using Docbook entities.
      # def obfuscate(text)
      #   result = ""
      #   text.each_byte do |b|
      #     result << (b > 128 ? b.chr : "&#%03d;" % b)
      #   end
      #   result.force_encoding(text.encoding) if result.respond_to?(:force_encoding)
      #   result
      # end

      # # Return a Docbook ordered list with the footnote content for the used footnotes.
      # def footnote_content
      #   ol = Element.new(:ol)
      #   ol.attr['start'] = @footnote_start if @footnote_start != 1
      #   @footnotes.each do |name, data|
      #     li = Element.new(:li, nil, {'id' => "fn:#{name}"})
      #     li.children = Marshal.load(Marshal.dump(data.children))
      #     ol.children << li

      #     ref = Element.new(:raw, "<a href=\"#fnref:#{name}\" rel=\"reference\">&#8617;</a>")
      #     if li.children.last.type == :p
      #       para = li.children.last
      #     else
      #       li.children << (para = Element.new(:p))
      #     end
      #     para.children << ref
      #   end
      #   (ol.children.empty? ? '' : "<div class=\"footnotes\">\n#{convert(ol, 2)}</div>\n")
      # end

    end

  end
end
