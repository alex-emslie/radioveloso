# frozen_string_literal: true

require "cgi"
require "action_view/helpers/tag_helper"
require "active_support/core_ext/string/output_safety"
require "active_support/core_ext/module/attribute_accessors"

module ActionView
  # = Action View Form Tag Helpers
  module Helpers #:nodoc:
    # Provides a number of methods for creating form tags that don't rely on an Active Record object assigned to the template like
    # FormHelper does. Instead, you provide the names and values manually.
    #
    # NOTE: The HTML options <tt>disabled</tt>, <tt>readonly</tt>, and <tt>multiple</tt> can all be treated as booleans. So specifying
    # <tt>disabled: true</tt> will give <tt>disabled="disabled"</tt>.
    module FormTagHelper
      extend ActiveSupport::Concern

      include UrlHelper
      include TextHelper

      mattr_accessor :embed_authenticity_token_in_remote_forms
      self.embed_authenticity_token_in_remote_forms = nil

      mattr_accessor :default_enforce_utf8, default: true

      # Starts a form tag that points the action to a url configured with <tt>url_for_options</tt> just like
      # ActionController::Base#url_for. The method for the form defaults to POST.
      #
      # ==== Options
      # * <tt>:multipart</tt> - If set to true, the enctype is set to "multipart/form-data".
      # * <tt>:method</tt> - The method to use when submitting the form, usually either "get" or "post".
      #   If "patch", "put", "delete", or another verb is used, a hidden input with name <tt>_method</tt>
      #   is added to simulate the verb over post.
      # * <tt>:authenticity_token</tt> - Authenticity token to use in the form. Use only if you need to
      #   pass custom authenticity token string, or to not add authenticity_token field at all
      #   (by passing <tt>false</tt>).  Remote forms may omit the embedded authenticity token
      #   by setting <tt>config.action_view.embed_authenticity_token_in_remote_forms = false</tt>.
      #   This is helpful when you're fragment-caching the form. Remote forms get the
      #   authenticity token from the <tt>meta</tt> tag, so embedding is unnecessary unless you
      #   support browsers without JavaScript.
      # * <tt>:remote</tt> - If set to true, will allow the Unobtrusive JavaScript drivers to control the
      #   submit behavior. By default this behavior is an ajax submit.
      # * <tt>:enforce_utf8</tt> - If set to false, a hidden input with name utf8 is not output.
      # * Any other key creates standard HTML attributes for the tag.
      #
      # ==== Examples
      #   form_tag('/posts')
      #   # => <form action="/posts" method="post">
      #
      #   form_tag('/posts/1', method: :put)
      #   # => <form action="/posts/1" method="post"> ... <input name="_method" type="hidden" value="put" /> ...
      #
      #   form_tag('/upload', multipart: true)
      #   # => <form action="/upload" method="post" enctype="multipart/form-data">
      #
      #   <%= form_tag('/posts') do -%>
      #     <div><%= submit_tag 'Save' %></div>
      #   <% end -%>
      #   # => <form action="/posts" method="post"><div><input type="submit" name="commit" value="Save" /></div></form>
      #
      #   <%= form_tag('/posts', remote: true) %>
      #   # => <form action="/posts" method="post" data-remote="true">
      #
      #   form_tag('http://far.away.com/form', authenticity_token: false)
      #   # form without authenticity token
      #
      #   form_tag('http://far.away.com/form', authenticity_token: "cf50faa3fe97702ca1ae")
      #   # form with custom authenticity token
      #
      def form_tag(url_for_options = {}, options = {}, &block)
        html_options = html_options_for_form(url_for_options, options)
        if block_given?
          form_tag_with_body(html_options, capture(&block))
        else
          form_tag_html(html_options)
        end
      end

      # Creates a dropdown selection box, or if the <tt>:multiple</tt> option is set to true, a multiple
      # choice selection box.
      #
      # Helpers::FormOptions can be used to create common select boxes such as countries, time zones, or
      # associated records. <tt>option_tags</tt> is a string containing the option tags for the select box.
      #
      # ==== Options
      # * <tt>:multiple</tt> - If set to true, the selection will allow multiple choices.
      # * <tt>:disabled</tt> - If set to true, the user will not be able to use this input.
      # * <tt>:include_blank</tt> - If set to true, an empty option will be created. If set to a string, the string will be used as the option's content and the value will be empty.
      # * <tt>:prompt</tt> - Create a prompt option with blank value and the text asking user to select something.
      # * Any other key creates standard HTML attributes for the tag.
      #
      # ==== Examples
      #   select_tag "people", options_from_collection_for_select(@people, "id", "name")
      #   # <select id="people" name="people"><option value="1">David</option></select>
      #
      #   select_tag "people", options_from_collection_for_select(@people, "id", "name", "1")
      #   # <select id="people" name="people"><option value="1" selected="selected">David</option></select>
      #
      #   select_tag "people", raw("<option>David</option>")
      #   # => <select id="people" name="people"><option>David</option></select>
      #
      #   select_tag "count", raw("<option>1</option><option>2</option><option>3</option><option>4</option>")
      #   # => <select id="count" name="count"><option>1</option><option>2</option>
      #   #    <option>3</option><option>4</option></select>
      #
      #   select_tag "colors", raw("<option>Red</option><option>Green</option><option>Blue</option>"), multiple: true
      #   # => <select id="colors" multiple="multiple" name="colors[]"><option>Red</option>
      #   #    <option>Green</option><option>Blue</option></select>
      #
      #   select_tag "locations", raw("<option>Home</option><option selected='selected'>Work</option><option>Out</option>")
      #   # => <select id="locations" name="locations"><option>Home</option><option selected='selected'>Work</option>
      #   #    <option>Out</option></select>
      #
      #   select_tag "access", raw("<option>Read</option><option>Write</option>"), multiple: true, class: 'form_input', id: 'unique_id'
      #   # => <select class="form_input" id="unique_id" multiple="multiple" name="access[]"><option>Read</option>
      #   #    <option>Write</option></select>
      #
      #   select_tag "people", options_from_collection_for_select(@people, "id", "name"), include_blank: true
      #   # => <select id="people" name="people"><option value="" label=" "></option><option value="1">David</option></select>
      #
      #   select_tag "people", options_from_collection_for_select(@people, "id", "name"), include_blank: "All"
      #   # => <select id="people" name="people"><option value="">All</option><option value="1">David</option></select>
      #
      #   select_tag "people", options_from_collection_for_select(@people, "id", "name"), prompt: "Select something"
      #   # => <select id="people" name="people"><option value="">Select something</option><option value="1">David</option></select>
      #
      #   select_tag "destination", raw("<option>NYC</option><option>Paris</option><option>Rome</option>"), disabled: true
      #   # => <select disabled="disabled" id="destination" name="destination"><option>NYC</option>
      #   #    <option>Paris</option><option>Rome</option></select>
      #
      #   select_tag "credit_card", options_for_select([ "VISA", "MasterCard" ], "MasterCard")
      #   # => <select id="credit_card" name="credit_card"><option>VISA</option>
      #   #    <option selected="selected">MasterCard</option></select>
      def select_tag(name, option_tags = nil, options = {})
        option_tags ||= ""
        html_name = (options[:multiple] == true && !name.to_s.ends_with?("[]")) ? "#{name}[]" : name

        if options.include?(:include_blank)
          include_blank = options.delete(:include_blank)
          options_for_blank_options_tag = { value: "" }

          if include_blank == true
            include_blank = ""
            options_for_blank_options_tag[:label] = " "
          end

          if include_blank
            option_tags = content_tag("option".freeze, include_blank, options_for_blank_options_tag).safe_concat(option_tags)
          end
        end

        if prompt = options.delete(:prompt)
          option_tags = content_tag("option".freeze, prompt, value: "").safe_concat(option_tags)
        end

        content_tag "select".freeze, option_tags, { "name" => html_name, "id" => sanitize_to_id(name) }.update(options.stringify_keys)
      end

      # Creates a standard text field; use these text fields to input smaller chunks of text like a username
      # or a search query.
      #
      # ==== Options
      # * <tt>:disabled</tt> - If set to true, the user will not be able to use this input.
      # * <tt>:size</tt> - The number of visible characters that will fit in the input.
      # * <tt>:maxlength</tt> - The maximum number of characters that the browser will allow the user to enter.
      # * <tt>:placeholder</tt> - The text contained in the field by default which is removed when the field receives focus.
      # * Any other key creates standard HTML attributes for the tag.
      #
      # ==== Examples
      #   text_field_tag 'name'
      #   # => <input id="name" name="name" type="text" />
      #
      #   text_field_tag 'query', 'Enter your search query here'
      #   # => <input id="query" name="query" type="text" value="Enter your search query here" />
      #
      #   text_field_tag 'search', nil, placeholder: 'Enter search term...'
      #   # => <input id="search" name="search" placeholder="Enter search term..." type="text" />
      #
      #   text_field_tag 'request', nil, class: 'special_input'
      #   # => <input class="special_input" id="request" name="request" type="text" />
      #
      #   text_field_tag 'address', '', size: 75
      #   # => <input id="address" name="address" size="75" type="text" value="" />
      #
      #   text_field_tag 'zip', nil, maxlength: 5
      #   # => <input id="zip" maxlength="5" name="zip" type="text" />
      #
      #   text_field_tag 'payment_amount', '$0.00', disabled: true
      #   # => <input disabled="disabled" id="payment_amount" name="payment_amount" type="text" value="$0.00" />
      #
      #   text_field_tag 'ip', '0.0.0.0', maxlength: 15, size: 20, class: "ip-input"
      #   # => <input class="ip-input" id="ip" maxlength="15" name="ip" size="20" type="text" value="0.0.0.0" />
      def text_field_tag(name, value = nil, options = {})
        tag :input, { "type" => "text", "name" => name, "id" => sanitize_to_id(name), "value" => value }.update(options.stringify_keys)
      end

      # Creates a label element. Accepts a block.
      #
      # ==== Options
      # * Creates standard HTML attributes for the tag.
      #
      # ==== Examples
      #   label_tag 'name'
      #   # => <label for="name">Name</label>
      #
      #   label_tag 'name', 'Your name'
      #   # => <label for="name">Your name</label>
      #
      #   label_tag 'name', nil, class: 'small_label'
      #   # => <label for="name" class="small_label">Name</label>
      def label_tag(name = nil, content_or_options = nil, options = nil, &block)
        if block_given? && content_or_options.is_a?(Hash)
          options = content_or_options = content_or_options.stringify_keys
        else
          options ||= {}
          options = options.stringify_keys
        end
        options["for"] = sanitize_to_id(name) unless name.blank? || options.has_key?("for")
        content_tag :label, content_or_options || name.to_s.humanize, options, &block
      end

      # Creates a hidden form input field used to transmit data that would be lost due to HTTP's statelessness or
      # data that should be hidden from the user.
      #
      # ==== Options
      # * Creates standard HTML attributes for the tag.
      #
      # ==== Examples
      #   hidden_field_tag 'tags_list'
      #   # => <input id="tags_list" name="tags_list" type="hidden" />
      #
      #   hidden_field_tag 'token', 'VUBJKB23UIVI1UU1VOBVI@'
      #   # => <input id="token" name="token" type="hidden" value="VUBJKB23UIVI1UU1VOBVI@" />
      #
      #   hidden_field_tag 'collected_input', '', onchange: "alert('Input collected!')"
      #   # => <input id="collected_input" name="collected_input" onchange="alert('Input collected!')"
      #   #    type="hidden" value="" />
      def hidden_field_tag(name, value = nil, options = {})
        text_field_tag(name, value, options.merge(type: :hidden))
      end

      # Creates a file upload field. If you are using file uploads then you will also need
      # to set the multipart option for the form tag:
      #
      #   <%= form_tag '/upload', multipart: true do %>
      #     <label for="file">File to Upload</label> <%= file_field_tag "file" %>
      #     <%= submit_tag %>
      #   <% end %>
      #
      # The specified URL will then be passed a File object containing the selected file, or if the field
      # was left blank, a StringIO object.
      #
      # ==== Options
      # * Creates standard HTML attributes for the tag.
      # * <tt>:disabled</tt> - If set to true, the user will not be able to use this input.
      # * <tt>:multiple</tt> - If set to true, *in most updated browsers* the user will be allowed to select multiple files.
      # * <tt>:accept</tt> - If set to one or multiple mime-types, the user will be suggested a filter when choosing a file. You still need to set up model validations.
      #
      # ==== Examples
      #   file_field_tag 'attachment'
      #   # => <input id="attachment" name="attachment" type="file" />
      #
      #   file_field_tag 'avatar', class: 'profile_input'
      #   # => <input class="profile_input" id="avatar" name="avatar" type="file" />
      #
      #   file_field_tag 'picture', disabled: true
      #   # => <input disabled="disabled" id="picture" name="picture" type="file" />
      #
      #   file_field_tag 'resume', value: '~/resume.doc'
      #   # => <input id="resume" name="resume" type="file" value="~/resume.doc" />
      #
      #   file_field_tag 'user_pic', accept: 'image/png,image/gif,image/jpeg'
      #   # => <input accept="image/png,image/gif,image/jpeg" id="user_pic" name="user_pic" type="file" />
      #
      #   file_field_tag 'file', accept: 'text/html', class: 'upload', value: 'index.html'
      #   # => <input accept="text/html" class="upload" id="file" name="file" type="file" value="index.html" />
      def file_field_tag(name, options = {})
        text_field_tag(name, nil, convert_direct_upload_option_to_url(options.merge(type: :file)))
      end

      # Creates a password field, a masked text field that will hide the users input behind a mask character.
      #
      # ==== Options
      # * <tt>:disabled</tt> - If set to true, the user will not be able to use this input.
      # * <tt>:size</tt> - The number of visible characters that will fit in the input.
      # * <tt>:maxlength</tt> - The maximum number of characters that the browser will allow the user to enter.
      # * Any other key creates standard HTML attributes for the tag.
      #
      # ==== Examples
      #   password_field_tag 'pass'
      #   # => <input id="pass" name="pass" type="password" />
      #
      #   password_field_tag 'secret', 'Your secret here'
      #   # => <input id="secret" name="secret" type="password" value="Your secret here" />
      #
      #   password_field_tag 'masked', nil, class: 'masked_input_field'
      #   # => <input class="masked_input_field" id="masked" name="masked" type="password" />
      #
      #   password_field_tag 'token', '', size: 15
      #   # => <input id="token" name="token" size="15" type="password" value="" />
      #
      #   password_field_tag 'key', nil, maxlength: 16
      #   # => <input id="key" maxlength="16" name="key" type="password" />
      #
      #   password_field_tag 'confirm_pass', nil, disabled: true
      #   # => <input disabled="disabled" id="confirm_pass" name="confirm_pass" type="password" />
      #
      #   password_field_tag 'pin', '1234', maxlength: 4, size: 6, class: "pin_input"
      #   # => <input class="pin_input" id="pin" maxlength="4" name="pin" size="6" type="password" value="1234" />
      def password_field_tag(name = "password", value = nil, options = {})
        text_field_tag(name, value, options.merge(type: :password))
      end

      # Creates a text input area; use a textarea for longer text inputs such as blog posts or descriptions.
      #
      # ==== Options
      # * <tt>:size</tt> - A string specifying the dimensions (columns by rows) of the textarea (e.g., "25x10").
      # * <tt>:rows</tt> - Specify the number of rows in the textarea
      # * <tt>:cols</tt> - Specify the number of columns in the textarea
      # * <tt>:disabled</tt> - If set to true, the user will not be able to use this input.
      # * <tt>:escape</tt> - By default, the contents of the text input are HTML escaped.
      #   If you need unescaped contents, set this to false.
      # * Any other key creates standard HTML attributes for the tag.
      #
      # ==== Examples
      #   text_area_tag 'post'
      #   # => <textarea id="post" name="post"></textarea>
      #
      #   text_area_tag 'bio', @user.bio
      #   # => <textarea id="bio" name="bio">This is my biography.</textarea>
      #
      #   text_area_tag 'body', nil, rows: 10, cols: 25
      #   # => <textarea cols="25" id="body" name="body" rows="10"></textarea>
      #
      #   text_area_tag 'body', nil, size: "25x10"
      #   # => <textarea name="body" id="body" cols="25" rows="10"></textarea>
      #
      #   text_area_tag 'description', "Description goes here.", disabled: true
      #   # => <textarea disabled="disabled" id="description" name="description">Description goes here.</textarea>
      #
      #   text_area_tag 'comment', nil, class: 'comment_input'
      #   # => <textarea class="comment_input" id="comment" name="comment"></textarea>
      def text_area_tag(name, content = nil, options = {})
        options = options.stringify_keys

        if size = options.delete("size")
          options["cols"], options["rows"] = size.split("x") if size.respond_to?(:split)
        end

        escape = options.delete("escape") { true }
        content = ERB::Util.html_escape(content) if escape

        content_tag :textarea, content.to_s.html_safe, { "name" => name, "id" => sanitize_to_id(name) }.update(options)
      end

      # Creates a check box form input tag.
      #
      # ==== Options
      # * <tt>:disabled</tt> - If set to true, the user will not be able to use this input.
      # * Any other key creates standard HTML options for the tag.
      #
      # ==== Examples
      #   check_box_tag 'accept'
      #   # => <input id="accept" name="accept" type="checkbox" value="1" />
      #
      #   check_box_tag 'rock', 'rock music'
      #   # => <input id="rock" name="rock" type="checkbox" value="rock music" />
      #
      #   check_box_tag 'receive_email', 'yes', true
      #   # => <input checked="checked" id="receive_email" name="receive_email" type="checkbox" value="yes" />
      #
      #   check_box_tag 'tos', 'yes', false, class: 'accept_tos'
      #   # => <input class="accept_tos" id="tos" name="tos" type="checkbox" value="yes" />
      #
      #   check_box_tag 'eula', 'accepted', false, disabled: true
      #   # => <input disabled="disabled" id="eula" name="eula" type="checkbox" value="accepted" />
      def check_box_tag(name, value = "1", checked = false, options = {})
        html_options = { "type" => "checkbox", "name" => name, "id" => sanitize_to_id(name), "value" => value }.update(options.stringify_keys)
        html_options["checked"] = "checked" if checked
        tag :input, html_options
      end

      # Creates a radio button; use groups of radio buttons named the same to allow users to
      # select from a group of options.
      #
      # ==== Options
      # * <tt>:disabled</tt> - If set to true, the user will not be able to use this input.
      # * Any other key creates standard HTML options for the tag.
      #
      # ==== Examples
      #   radio_button_tag 'favorite_color', 'maroon'
      #   # => <input id="favorite_color_maroon" name="favorite_color" type="radio" value="maroon" />
      #
      #   radio_button_tag 'receive_updates', 'no', true
      #   # => <input checked="checked" id="receive_updates_no" name="receive_updates" type="radio" value="no" />
      #
      #   radio_button_tag 'time_slot', "3:00 p.m.", false, disabled: true
      #   # => <input disabled="disabled" id="time_slot_3:00_p.m." name="time_slot" type="radio" value="3:00 p.m." />
      #
      #   radio_button_tag 'color', "green", true, class: "color_input"
      #   # => <input checked="checked" class="color_input" id="color_green" name="color" type="radio" value="green" />
      def radio_button_tag(name, value, checked = false, options = {})
        html_options = { "type" => "radio", "name" => name, "id" => "#{sanitize_to_id(name)}_#{sanitize_to_id(value)}", "value" => value }.update(options.stringify_keys)
        html_options["checked"] = "checked" if checked
        tag :input, html_options
      end

      # Creates a submit button with the text <tt>value</tt> as the caption.
      #
      # ==== Options
      # * <tt>:data</tt> - This option can be used to add custom data attributes.
      # * <tt>:disabled</tt> - If true, the user will not be able to use this input.
      # * Any other key creates standard HTML options for the tag.
      #
      # ==== Data attributes
      #
      # * <tt>confirm: 'question?'</tt> - If present the unobtrusive JavaScript
      #   drivers will provide a prompt with the question specified. If the user accepts,
      #   the form is processed normally, otherwise no action is taken.
      # * <tt>:disable_with</tt> - Value of this parameter will be used as the value for a
      #   disabled version of the submit button when the form is submitted. This feature is
      #   provided by the unobtrusive JavaScript driver. To disable this feature for a single submit tag
      #   pass <tt>:data => { disable_with: false }</tt> Defaults to value attribute.
      #
      # ==== Examples
      #   submit_tag
      #   # => <input name="commit" data-disable-with="Save changes" type="submit" value="Save changes" />
      #
      #   submit_tag "Edit this article"
      #   # => <input name="commit" data-disable-with="Edit this article" type="submit" value="Edit this article" />
      #
      #   submit_tag "Save edits", disabled: true
      #   # => <input disabled="disabled" name="commit" data-disable-with="Save edits" type="submit" value="Save edits" />
      #
      #   submit_tag "Complete sale", data: { disable_with: "Submitting..." }
      #   # => <input name="commit" data-disable-with="Submitting..." type="submit" value="Complete sale" />
      #
      #   submit_tag nil, class: "form_submit"
      #   # => <input class="form_submit" name="commit" type="submit" />
      #
      #   submit_tag "Edit", class: "edit_button"
      #   # => <input class="edit_button" data-disable-with="Edit" name="commit" type="submit" value="Edit" />
      #
      #   submit_tag "Save", data: { confirm: "Are you sure?" }
      #   # => <input name='commit' type='submit' value='Save' data-disable-with="Save" data-confirm="Are you sure?" />
      #
      def submit_tag(value = "Save changes", options = {})
        options = options.deep_stringify_keys
        tag_options = { "type" => "submit", "name" => "commit", "value" => value }.update(options)
        set_default_disable_with value, tag_options
        tag :input, tag_options
      end

      # Creates a button element that defines a <tt>submit</tt> button,
      # <tt>reset</tt> button or a generic button which can be used in
      # JavaScript, for example. You can use the button tag as a regular
      # submit tag but it isn't supported in legacy browsers. However,
      # the button tag does allow for richer labels such as images and emphasis,
      # so this helper will also accept a block. By default, it will create
      # a button tag with type <tt>submit</tt>, if type is not given.
      #
      # ==== Options
      # * <tt>:data</tt> - This option can be used to add custom data attributes.
      # * <tt>:disabled</tt> - If true, the user will not be able to
      #   use this input.
      # * Any other key creates standard HTML options for the tag.
      #
      # ==== Data attributes
      #
      # * <tt>confirm: 'question?'</tt> - If present, the
      #   unobtrusive JavaScript drivers will provide a prompt with
      #   the question specified. If the user accepts, the form is
      #   processed normally, otherwise no action is taken.
      # * <tt>:disable_with</tt> - Value of this parameter will be
      #   used as the value for a disabled version of the submit
      #   button when the form is submitted. This feature is provided
      #   by the unobtrusive JavaScript driver.
      #
      # ==== Examples
      #   button_tag
      #   # => <button name="button" type="submit">Button</button>
      #
      #   button_tag 'Reset', type: 'reset'
      #   # => <button name="button" type="reset">Reset</button>
      #
      #   button_tag 'Button', type: 'button'
      #   # => <button name="button" type="button">Button</button>
      #
      #   button_tag 'Reset', type: 'reset', disabled: true
      #   # => <button name="button" type="reset" disabled="disabled">Reset</button>
      #
      #   button_tag(type: 'button') do
      #     content_tag(:strong, 'Ask me!')
      #   end
      #   # => <button name="button" type="button">
      #   #     <strong>Ask me!</strong>
      #   #    </button>
      #
      #   button_tag "Save", data: { confirm: "Are you sure?" }
      #   # => <button name="button" type="submit" data-confirm="Are you sure?">Save</button>
      #
      #   button_tag "Checkout", data: { disable_with: "Please wait..." }
      #   # => <button data-disable-with="Please wait..." name="button" type="submit">Checkout</button>
      #
      def button_tag(content_or_options = nil, options = nil, &block)
        if content_or_options.is_a? Hash
          options = content_or_options
        else
          options ||= {}
        end

        options = { "name" => "button", "type" => "submit" }.merge!(options.stringify_keys)

        if block_given?
          content_tag :button, options, &block
        else
          content_tag :button, content_or_options || "Button", options
        end
      end

      # Displays an image which when clicked will submit the form.
      #
      # <tt>source</tt> is passed to AssetTagHelper#path_to_image
      #
      # ==== Options
      # * <tt>:data</tt> - This option can be used to add custom data attributes.
      # * <tt>:disabled</tt> - If set to true, the user will not be able to use this input.
      # * Any other key creates standard HTML options for the tag.
      #
      # ==== Data attributes
      #
      # * <tt>confirm: 'question?'</tt> - This will add a JavaScript confirm
      #   prompt with the question specified. If the user accepts, the form is
      #   processed normally, otherwise no action is taken.
      #
      # ==== Examples
      #   image_submit_tag("login.png")
      #   # => <input src="/assets/login.png" type="image" />
      #
      #   image_submit_tag("purchase.png", disabled: true)
      #   # => <input disabled="disabled" src="/assets/purchase.png" type="image" />
      #
      #   image_submit_tag("search.png", class: 'search_button', alt: 'Find')
      #   # => <input class="search_button" src="/assets/search.png" type="image" />
      #
      #   image_submit_tag("agree.png", disabled: true, class: "agree_disagree_button")
      #   # => <input class="agree_disagree_button" disabled="disabled" src="/assets/agree.png" type="image" />
      #
      #   image_submit_tag("save.png", data: { confirm: "Are you sure?" })
      #   # => <input src="/assets/save.png" data-confirm="Are you sure?" type="image" />
      def image_submit_tag(source, options = {})
        options = options.stringify_keys
        src = path_to_image(source, skip_pipeline: options.delete("skip_pipeline"))
        tag :input, { "type" => "image", "src" => src }.update(options)
      end

      # Creates a field set for grouping HTML form elements.
      #
      # <tt>legend</tt> will become the fieldset's title (optional as per W3C).
      # <tt>options</tt> accept the same values as tag.
      #
      # ==== Examples
      #   <%= field_set_tag do %>
      #     <p><%= text_field_tag 'name' %></p>
      #   <% end %>
      #   # => <fieldset><p><input id="name" name="name" type="text" /></p></fieldset>
      #
      #   <%= field_set_tag 'Your details' do %>
      #     <p><%= text_field_tag 'name' %></p>
      #   <% end %>
      #   # => <fieldset><legend>Your details</legend><p><input id="name" name="name" type="text" /></p></fieldset>
      #
      #   <%= field_set_tag nil, class: 'format' do %>
      #     <p><%= text_field_tag 'name' %></p>
      #   <% end %>
      #   # => <fieldset class="format"><p><input id="name" name="name" type="text" /></p></fieldset>
      def field_set_tag(legend = nil, options = nil, &block)
        output = tag(:fieldset, options, true)
        output.safe_concat(content_tag("legend".freeze, legend)) unless legend.blank?
        output.concat(capture(&block)) if block_given?
        output.safe_concat("</fieldset>")
      end

      # Creates a text field of type "color".
      #
      # ==== Options
      # * Accepts the same options as text_field_tag.
      #
      # ==== Examples
      #   color_field_tag 'name'
      #   # => <input id="name" name="name" type="color" />
      #
      #   color_field_tag 'color', '#DEF726'
      #   # => <input id="color" name="color" type="color" value="#DEF726" />
      #
      #   color_field_tag 'color', nil, class: 'special_input'
      #   # => <input class="special_input" id="color" name="color" type="color" />
      #
      #   color_field_tag 'color', '#DEF726', class: 'special_input', disabled: true
      #   # => <input disabled="disabled" class="special_input" id="color" name="color" type="color" value="#DEF726" />
      def color_field_tag(name, value = nil, options = {})
        text_field_tag(name, value, options.merge(type: :color))
      end

      # Creates a text field of type "search".
      #
      # ==== Options
      # * Accepts the same options as text_field_tag.
      #
      # ==== Examples
      #   search_field_tag 'name'
      #   # => <input id="name" name="name" type="search" />
      #
      #   search_field_tag 'search', 'Enter your search query here'
      #   # => <input id="search" name="search" type="search" value="Enter your search query here" />
      #
      #   search_field_tag 'search', nil, class: 'special_input'
      #   # => <input class="special_input" id="search" name="search" type="search" />
      #
      #   search_field_tag 'search', 'Enter your search query here', class: 'special_input', disabled: true
      #   # => <input disabled="disabled" class="special_input" id="search" name="search" type="search" value="Enter your search query here" />
      def search_field_tag(name, value = nil, options = {})
        text_field_tag(name, value, options.merge(type: :search))
      end

      # Creates a text field of type "tel".
      #
      # ==== Options
      # * Accepts the same options as text_field_tag.
      #
      # ==== Examples
      #   telephone_field_tag 'name'
      #   # => <input id="name" name="name" type="tel" />
      #
      #   telephone_field_tag 'tel', '0123456789'
      #   # => <input id="tel" name="tel" type="tel" value="0123456789" />
      #
      #   telephone_field_tag 'tel', nil, class: 'special_input'
      #   # => <input class="special_input" id="tel" name="tel" type="tel" />
      #
      #   telephone_field_tag 'tel', '0123456789', class: 'special_input', disabled: true
      #   # => <input disabled="disabled" class="special_input" id="tel" name="tel" type="tel" value="0123456789" />
      def telephone_field_tag(name, value = nil, options = {})
        text_field_tag(name, value, options.merge(type: :tel))
      end
      alias phone_field_tag telephone_field_tag

      # Creates a text field of type "date".
      #
      # ==== Options
      # * Accepts the same options as text_field_tag.
      #
      # ==== Examples
      #   date_field_tag 'name'
      #   # => <input id="name" name="name" type="date" />
      #
      #   date_field_tag 'date', '01/01/2014'
      #   # => <input id="date" name="date" type="date" value="01/01/2014" />
      #
      #   date_field_tag 'date', nil, class: 'special_input'
      #   # => <input class="special_input" id="date" name="date" type="date" />
      #
      #   date_field_tag 'date', '01/01/2014', class: 'special_input', disabled: true
      #   # => <input disabled="disabled" class="special_input" id="date" name="date" type="date" value="01/01/2014" />
      def date_field_tag(name, value = nil, options = {})
        text_field_tag(name, value, options.merge(type: :date))
      end

      # Creates a text field of type "time".
      #
      # === Options
      # * <tt>:min</tt> - The minimum acceptable value.
      # * <tt>:max</tt> - The maximum acceptable value.
      # * <tt>:step</tt> - The acceptable value granularity.
      # * Otherwise accepts the same options as text_field_tag.
      def time_field_tag(name, value = nil, options = {})
        text_field_tag(name, value, options.merge(type: :time))
      end

      # Creates a text field of type "datetime-local".
      #
      # === Options
      # * <tt>:min</tt> - The minimum acceptable value.
      # * <tt>:max</tt> - The maximum acceptable value.
      # * <tt>:step</tt> - The acceptable value granularity.
      # * Otherwise accepts the same options as text_field_tag.
      def datetime_field_tag(name, value = nil, options = {})
        text_field_tag(name, value, options.merge(type: "datetime-local"))
      end

      alias datetime_local_field_tag datetime_field_tag

      # Creates a text field of type "month".
      #
      # === Options
      # * <tt>:min</tt> - The minimum acceptable value.
      # * <tt>:max</tt> - The maximum acceptable value.
      # * <tt>:step</tt> - The acceptable value granularity.
      # * Otherwise accepts the same options as text_field_tag.
      def month_field_tag(name, value = nil, options = {})
        text_field_tag(name, value, options.merge(type: :month))
      end

      # Creates a text field of type "week".
      #
      # === Options
      # * <tt>:min</tt> - The minimum acceptable value.
      # * <tt>:max</tt> - The maximum acceptable value.
      # * <tt>:step</tt> - The acceptable value granularity.
      # * Otherwise accepts the same options as text_field_tag.
      def week_field_tag(name, value = nil, options = {})
        text_field_tag(name, value, options.merge(type: :week))
      end

      # Creates a text field of type "url".
      #
      # ==== Options
      # * Accepts the same options as text_field_tag.
      #
      # ==== Examples
      #   url_field_tag 'name'
      #   # => <input id="name" name="name" type="url" />
      #
      #   url_field_tag 'url', 'http://rubyonrails.org'
      #   # => <input id="url" name="url" type="url" value="http://rubyonrails.org" />
      #
      #   url_field_tag 'url', nil, class: 'special_input'
      #   # => <input class="special_input" id="url" name="url" type="url" />
      #
      #   url_field_tag 'url', 'http://rubyonrails.org', class: 'special_input', disabled: true
      #   # => <input disabled="disabled" class="special_input" id="url" name="url" type="url" value="http://rubyonrails.org" />
      def url_field_tag(name, value = nil, options = {})
        text_field_tag(name, value, options.merge(type: :url))
      end

      # Creates a text field of type "email".
      #
      # ==== Options
      # * Accepts the same options as text_field_tag.
      #
      # ==== Examples
      #   email_field_tag 'name'
      #   # => <input id="name" name="name" type="email" />
      #
      #   email_field_tag 'email', 'email@example.com'
      #   # => <input id="email" name="email" type="email" value="email@example.com" />
      #
      #   email_field_tag 'email', nil, class: 'special_input'
      #   # => <input class="special_input" id="email" name="email" type="email" />
      #
      #   email_field_tag 'email', 'email@example.com', class: 'special_input', disabled: true
      #   # => <input disabled="disabled" class="special_input" id="email" name="email" type="email" value="email@example.com" />
      def email_field_tag(name, value = nil, options = {})
        text_field_tag(name, value, options.merge(type: :email))
      end

      # Creates a number field.
      #
      # ==== Options
      # * <tt>:min</tt> - The minimum acceptable value.
      # * <tt>:max</tt> - The maximum acceptable value.
      # * <tt>:in</tt> - A range specifying the <tt>:min</tt> and
      #   <tt>:max</tt> values.
      # * <tt>:within</tt> - Same as <tt>:in</tt>.
      # * <tt>:step</tt> - The acceptable value granularity.
      # * Otherwise accepts the same options as text_field_tag.
      #
      # ==== Examples
      #   number_field_tag 'quantity'
      #   # => <input id="quantity" name="quantity" type="number" />
      #
      #   number_field_tag 'quantity', '1'
      #   # => <input id="quantity" name="quantity" type="number" value="1" />
      #
      #   number_field_tag 'quantity', nil, class: 'special_input'
      #   # => <input class="special_input" id="quantity" name="quantity" type="number" />
      #
      #   number_field_tag 'quantity', nil, min: 1
      #   # => <input id="quantity" name="quantity" min="1" type="number" />
      #
      #   number_field_tag 'quantity', nil, max: 9
      #   # => <input id="quantity" name="quantity" max="9" type="number" />
      #
      #   number_field_tag 'quantity', nil, in: 1...10
      #   # => <input id="quantity" name="quantity" min="1" max="9" type="number" />
      #
      #   number_field_tag 'quantity', nil, within: 1...10
      #   # => <input id="quantity" name="quantity" min="1" max="9" type="number" />
      #
      #   number_field_tag 'quantity', nil, min: 1, max: 10
      #   # => <input id="quantity" name="quantity" min="1" max="10" type="number" />
      #
      #   number_field_tag 'quantity', nil, min: 1, max: 10, step: 2
      #   # => <input id="quantity" name="quantity" min="1" max="10" step="2" type="number" />
      #
      #   number_field_tag 'quantity', '1', class: 'special_input', disabled: true
      #   # => <input disabled="disabled" class="special_input" id="quantity" name="quantity" type="number" value="1" />
      def number_field_tag(name, value = nil, options = {})
        options = options.stringify_keys
        options["type"] ||= "number"
        if range = options.delete("in") || options.delete("within")
          options.update("min" => range.min, "max" => range.max)
        end
        text_field_tag(name, value, options)
      end

      # Creates a range form element.
      #
      # ==== Options
      # * Accepts the same options as number_field_tag.
      def range_field_tag(name, value = nil, options = {})
        number_field_tag(name, value, options.merge(type: :range))
      end

      # Creates the hidden UTF8 enforcer tag. Override this method in a helper
      # to customize the tag.
      def utf8_enforcer_tag
        # Use raw HTML to ensure the value is written as an HTML entity; it
        # needs to be the right character regardless of which encoding the
        # browser infers.
        '<input name="utf8" type="hidden" value="&#x2713;" />'.html_safe
      end

      private
        def html_options_for_form(url_for_options, options)
          options.stringify_keys.tap do |html_options|
            html_options["enctype"] = "multipart/form-data" if html_options.delete("multipart")
            # The following URL is unescaped, this is just a hash of options, and it is the
            # responsibility of the caller to escape all the values.
            html_options["action"]  = url_for(url_for_options)
            html_options["accept-charset"] = "UTF-8"

            html_options["data-remote"] = true if html_options.delete("remote")

            if html_options["data-remote"] &&
               !embed_authenticity_token_in_remote_forms &&
               html_options["authenticity_token"].blank?
              # The authenticity token is taken from the meta tag in this case
              html_options["authenticity_token"] = false
            elsif html_options["authenticity_token"] == true
              # Include the default authenticity_token, which is only generated when its set to nil,
              # but we needed the true value to override the default of no authenticity_token on data-remote.
              html_options["authenticity_token"] = nil
            end
          end
        end

        def extra_tags_for_form(html_options)
          authenticity_token = html_options.delete("authenticity_token")
          method = html_options.delete("method").to_s.downcase

          method_tag = \
            case method
            when "get"
              html_options["method"] = "get"
              ""
            when "post", ""
              html_options["method"] = "post"
              token_tag(authenticity_token, form_options: {
                action: html_options["action"],
                method: "post"
              })
            else
              html_options["method"] = "post"
              method_tag(method) + token_tag(authenticity_token, form_options: {
                action: html_options["action"],
                method: method
              })
            end

          if html_options.delete("enforce_utf8") { default_enforce_utf8 }
            utf8_enforcer_tag + method_tag
          else
            method_tag
          end
        end

        def form_tag_html(html_options)
          extra_tags = extra_tags_for_form(html_options)
          tag(:form, html_options, true) + extra_tags
        end

        def form_tag_with_body(html_options, content)
          output = form_tag_html(html_options)
          output << content
          output.safe_concat("</form>")
        end

        # see http://www.w3.org/TR/html4/types.html#type-name
        def sanitize_to_id(name)
          name.to_s.delete("]").tr("^-a-zA-Z0-9:.", "_")
        end

        def set_default_disable_with(value, tag_options)
          return unless ActionView::Base.automatically_disable_submit_tag
          data = tag_options["data"]

          unless tag_options["data-disable-with"] == false || (data && data["disable_with"] == false)
            disable_with_text = tag_options["data-disable-with"]
            disable_with_text ||= data["disable_with"] if data
            disable_with_text ||= value.to_s.clone
            tag_options.deep_merge!("data" => { "disable_with" => disable_with_text })
          else
            data.delete("disable_with") if data
          end

          tag_options.delete("data-disable-with")
        end

        def convert_direct_upload_option_to_url(options)
          if options.delete(:direct_upload) && respond_to?(:rails_direct_uploads_url)
            options["data-direct-upload-url"] = rails_direct_uploads_url
          end
          options
        end
    end
  end
end
