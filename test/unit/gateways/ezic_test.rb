require "test_helper"

class EzicTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = EzicGateway.new(
      login: "login",
      password: "password"
    )

    @credit_card = credit_card
    @amount = 100
  end

  def test_successful_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    assert_success response

    assert_equal "849768440022761|Longbob Longsen", response.authorization
    assert response.test?
  end

  def test_failed_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(failed_purchase_response)

    assert_failure response
    assert_equal "Invalid Brand.", response.message
    assert_equal Gateway::STANDARD_ERROR_CODE[:invalid_number], response.error_code
    assert response.test?
  end

  def test_successful_authorize_and_capture
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal "2441955352022771|Longbob Longsen", response.authorization

    capture = stub_comms do
      @gateway.capture(@amount, response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/2441955352022771/, data)
    end.respond_with(successful_capture_response)

    assert_success capture
  end

  def test_failed_authorize
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(failed_authorize_response)

    assert_failure response
    assert_equal "Decline transaction", response.message
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
    assert response.test?
  end

  def test_failed_capture
    response = stub_comms do
      @gateway.capture(100, "")
    end.respond_with(failed_capture_response)

    assert_failure response
  end

  def test_successful_void
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal "P150100005006789", response.authorization

    void = stub_comms do
      @gateway.void(response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/P150100005006789/, data)
    end.respond_with(successful_void_response)

    assert_success void
  end

  def test_failed_void
    response = stub_comms do
      @gateway.void("5d53a33d960c46d00f5dc061947d998c")
    end.check_request do |endpoint, data, headers|
      assert_match(/5d53a33d960c46d00f5dc061947d998c/, data)
    end.respond_with(failed_void_response)

    assert_failure response
  end

  def test_successful_refund
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal "849768440022761|Longbob Longsen", response.authorization

    refund = stub_comms do
      @gateway.refund(@amount, response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/849768440022761/, data)
    end.respond_with(successful_refund_response)

    assert_success refund
  end

  def test_failed_refund
    response = stub_comms do
      @gateway.refund(nil, "")
    end.respond_with(failed_refund_response)

    assert_failure response
  end

  def test_successful_credit
    response = stub_comms do
      @gateway.credit(@amount, @credit_card)
    end.respond_with(successful_credit_response)

    assert_success response

    assert_equal "849768440022761|Longbob Longsen", response.authorization
    assert response.test?
  end

  def test_failed_credit
    response = stub_comms do
      @gateway.credit(@amount, @credit_card)
    end.respond_with(failed_credit_response)

    assert_failure response
    assert_equal "Invalid Brand.", response.message
    assert_equal Gateway::STANDARD_ERROR_CODE[:invalid_number], response.error_code
    assert response.test?
  end

  def test_successful_verify
    response = stub_comms do
      @gateway.verify(@credit_card)
    end.respond_with(successful_authorize_response, failed_void_response)
    assert_success response
    assert_equal "Succeeded", response.message
  end

  def test_failed_verify
    response = stub_comms do
      @gateway.verify(@credit_card)
    end.respond_with(failed_authorize_response, successful_void_response)
    assert_failure response
    assert_equal "Decline transaction", response.message
  end

  def test_successful_store
    response = stub_comms do
      @gateway.store(@credit_card)
    end.respond_with(successful_store_response)

    assert_success response

    assert_equal "Succeeded", response.message
    assert response.test?
  end

  def test_failed_store
    response = stub_comms do
      @gateway.store(@credit_card)
    end.respond_with(failed_store_response)

    assert_failure response
    assert_equal "Invalid card number (no such number)", response.message
    assert_equal Gateway::STANDARD_ERROR_CODE[:invalid_number], response.error_code
    assert response.test?
  end

  def test_empty_response_fails
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(empty_purchase_response)

    assert_failure response
    assert_equal "Unable to read error message", response.message
  end

  def test_transcript_scrubbing
    assert_equal scrubbed_transcript, @gateway.scrub(transcript)
  end

  private

  def successful_purchase_response
    %(
    )
  end

  def failed_purchase_response
    %(
    )
  end

  def successful_authorize_response
    %(
    )
  end

  def failed_authorize_response
    %(
    )
  end

  def successful_capture_response
    %(
    )
  end

  def failed_capture_response
    %(
    )
  end

  def successful_void_response
    %(
    )
  end

  def failed_void_response
    %(
    )
  end

  def successful_refund_response
    %(
    )
  end

  def failed_refund_response
    %(
    )
  end

  def successful_credit_response
    %(
    )
  end

  def failed_credit_response
    %(
    )
  end


  def successful_store_response
    %(
    )
  end

  def failed_store_response
    %(
    )
  end

  def empty_purchase_response
    %(
    )
  end

  def transcript
    %(
    )
  end

  def scrubbed_transcript
    %(
    )
  end
end
