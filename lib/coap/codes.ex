defmodule CoAP.Codes do

  defmacro __using__(_) do
    quote do

      @version 1

      @all_ipv4_address {224,0,1,187}
      @all_ipv6_address :"FF0X::FD" # How to represent an IPv6?

      @coap_port 5683
      @coaps_port 5684

      @types %{
        0 => :confirmable,
        1 => :non_confirmable,
        2 => :acknowledgement,
        3 => :reset
      }

      @types_reverse MapUtil.invert(@types)

      @classes %{
        0 => :request,
        2 => :success_response,
        4 => :client_error_response,
        5 => :server_error_response
      }

      @methods %{
        {0, 1} => :GET,
        {0, 2} => :POST,
        {0, 3} => :PUT,
        {0, 4} => :DELETE
      }

      @methods_reverse MapUtil.invert(@methods)

      @responses %{
        {0,  0} => :empty,
        {2,  0} => :ok,
        {2,  1} => :created,
        {2,  2} => :deleted,
        {2,  3} => :valid,
        {2,  4} => :changed,
        {2,  5} => :content,
        {4,  0} => :bad_request,
        {4,  1} => :unauthorized,
        {4,  2} => :bad_option,
        {4,  3} => :forbidden,
        {4,  4} => :not_found,
        {4,  5} => :method_not_allowed,
        {4,  6} => :not_acceptable,
        {4, 12} => :precondition_failed,
        {4, 13} => :request_entity_too_large,
        {4, 15} => :unsupported_content_format,
        {5,  0} => :internal_server_error,
        {5,  1} => :not_implemented,
        {5,  2} => :bad_gateway,
        {5,  3} => :service_unavailable,
        {5,  4} => :gateway_timeout,
        {5,  5} => :proxying_not_supported
      }

      @responses_reverse MapUtil.invert(@responses)

      @options %{
         1 => :if_match,
         3 => :uri_host,
         4 => :etag,
         5 => :if_none_match,
         6 => :observe,
         7 => :uri_port,
         8 => :location_path,
        11 => :uri_path,
        12 => :content_format,
        14 => :max_age,
        15 => :uri_query,
        17 => :accept,
        20 => :location_query,
        35 => :proxy_uri,
        39 => :proxy_scheme,
        60 => :size1
      }

      @options_reverse MapUtil.invert(@options)

      @option_formats %{
              :if_match => :opaque,
              :uri_host => :string,
                  :etag => :opaque,
         :if_none_match => :empty,
               :observe => :mixed,
              :uri_port => :uint,
         :location_path => :string,
              :uri_path => :string,
        :content_format => :uint,
               :max_age => :uint,
             :uri_query => :string,
                :accept => :uint,
        :location_query => :string,
             :proxy_uri => :string,
          :proxy_scheme => :string,
                 :size1 => :uint
      }

      @mime_types %{
         0 => :text_plain_charset_utf_8,
        40 => :application_link_format,
        41 => :application_xml,
        42 => :application_octet_stream,
        47 => :application_exi,
        50 => :application_json
      }

    end
  end

end
