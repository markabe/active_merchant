module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class EzicGateway < Gateway
      self.display_name = "Ezic, Inc."
      self.homepage_url = "http://ezic.com/"

      self.test_url = "https://secure-dm3.ezic.com/gw/sas/direct3.2"
      self.live_url = "https://secure-dm3.ezic.com/gw/sas/direct3.2"

      self.supported_countries = ["US"]
      self.default_currency = "USD"
      self.money_format = :cents
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      def initialize(options={})
        requires!(options, :account_id)
        super
      end

      def purchase(amount, payment_method, options={})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method)
        # add_customer_data(post, options)

        commit("A", post)
      end

      def authorize(amount, payment_method, options={})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method)
        add_customer_data(post, options)

        commit("authorize", post)
      end

      def capture(amount, authorization, options={})
        post = {}
        add_invoice(post, amount, options)
        add_reference(post, authorization)
        add_customer_data(post, options)

        commit("capture", post)
      end

      def void(authorization, options={})
        post = {}
        add_reference(post, authorization)
        commit("void", post)
      end

      def refund(amount, authorization, options={})
        post = {}
        add_invoice(post, amount, options)
        add_reference(post, authorization)
        add_customer_data(post, options)

        commit("refund", post)
      end

      def credit(amount, payment_method, options={})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method)

        commit("credit", post)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      # def store(payment_method, options = {})
      #   post = {}
      #   add_payment_method(post, payment_method)
      #   add_customer_data(post, options)

      #   commit("store", post)
      # end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r((card\[number\]=)\d+), '\1[FILTERED]').
          gsub(%r((card\[cvc\]=)\d+), '\1[FILTERED]')
      end

      private

      CURRENCY_CODES = Hash.new{|h,k| raise ArgumentError.new("Unsupported currency: #{k}")}
      CURRENCY_CODES["USD"] = "840"

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        # post[:orderid] = options[:order_id]
        # post[:currency] = CURRENCY_CODES[options[:currency] || currency(money)]
      end

      def add_payment_method(post, payment_method)
        # post[:cardholder] = payment_method.name
        post[:pay_type] = "C"
        post[:card_number] = payment_method.number
        # post[:cardcvv] = payment_method.verification_value
        post[:card_expire] = format(payment_method.month, :two_digits) + format(payment_method.year, :two_digits)
        # post[:cardtrackdata] = payment_method.track_data
      end

      def add_customer_data(post, options)
        post[:email] = options[:email]
        if(billing_address = (options[:billing_address] || options[:address]))
          post[:name] = billing_address[:name]
          post[:company] = billing_address[:company]
          post[:address1] = billing_address[:address1]
          post[:address2] = billing_address[:address2]
          post[:city] = billing_address[:city]
          post[:state] = billing_address[:state]
          post[:country] = billing_address[:country]
          post[:zip]    = billing_address[:zip]
          post[:phone] = billing_address[:phone]
        end
      end

      def add_reference(post, authorization)
        transaction_id, transaction_amount = split_authorization(authorization)
        post[:transaction_id] = transaction_id
        post[:transaction_amount] = transaction_amount
      end

      # ACTIONS = {
      #   "purchase" => "SALE",
      #   "authorize" => "AUTH",
      #   "capture" => "CAPTURE",
      #   "void" => "VOID",
      #   "refund" => "REFUND",
      #   "store" => "STORE",
      # }

      def commit(action, post)
        post[:account_id] = @options[:account_id]
        post[:tran_type] = action

        data = build_request(post)
        raw = parse(ssl_post(url(action), data, headers))

        succeeded = success_from(raw[:result])
        Response.new(
          succeeded,
          message_from(succeeded, raw),
          raw,
          authorization: authorization_from(post, raw),
          :avs_result => AVSResult.new(code: response["avs_response"]),
          :cvv_result => CVVResult.new(response["cvv2_response"]),
          error_code: error_code_from(succeeded, raw),
          test: test?
        )
      end

      def headers
        {
          # "Authorization" => "Basic " + Base64.encode64("#{@options[:login]}:#{@options[:password]}").strip,
          "Content-Type"  => "application/x-www-form-urlencoded",
          "User-Agent" => "ActiveMerchant/Version:2015.Mar.20"
        }
      end

      def build_request(post)
        post.to_query
      end

      def url(action)
        (test? ? test_url : live_url)
      end

      def parse(body)
        # urlencoded.
        Hash[CGI::parse(body).map{|k,v| [k.upcase,v.first]}]
      end

      def parse_element(response, node)
        if node.has_elements?
          node.elements.each{|element| parse_element(response, element) }
        else
          response[node.name.underscore.to_sym] = node.text
        end
      end

      def success_from(response)
        response == "SUCCESS"
      end

      def message_from(succeeded, response)
        if succeeded
          "Succeeded"
        else
          response[:error] || response[:message] || "Unable to read error message"
        end
      end

      STANDARD_ERROR_CODE_MAPPING = {
        "000000" => STANDARD_ERROR_CODE[:incorrect_number],
        "000000" => STANDARD_ERROR_CODE[:invalid_number],
        "000000" => STANDARD_ERROR_CODE[:invalid_expiry_date],
        "000000" => STANDARD_ERROR_CODE[:invalid_cvc],
        "000000" => STANDARD_ERROR_CODE[:expired_card],
        "000000" => STANDARD_ERROR_CODE[:incorrect_cvc],
        "000000" => STANDARD_ERROR_CODE[:incorrect_zip],
        "000000" => STANDARD_ERROR_CODE[:incorrect_address],
        "000000" => STANDARD_ERROR_CODE[:card_declined],
        "000000" => STANDARD_ERROR_CODE[:processing_error],
        "000000" => STANDARD_ERROR_CODE[:call_issuer],
        "000000" => STANDARD_ERROR_CODE[:pickup_card],
      }

      def authorization_from(request, response)
        [ response[:transaction_id], request[:transaction_amount] ].join("|")
      end

      def split_authorization(authorization)
        transaction_id, transaction_amount = authorization.split("|")
        [transaction_id, transaction_amount]
      end

      def error_code_from(succeeded, response)
        succeeded ? nil : STANDARD_ERROR_CODE_MAPPING[response[:error_code]]
      end
    end
  end
end
