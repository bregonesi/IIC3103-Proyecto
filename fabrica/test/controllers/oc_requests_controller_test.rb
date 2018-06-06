require 'test_helper'

class OcRequestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @oc_request = oc_requests(:one)
  end

  test "should get index" do
    get oc_requests_url
    assert_response :success
  end

  test "should get new" do
    get new_oc_request_url
    assert_response :success
  end

  test "should create oc_request" do
    assert_difference('OcRequest.count') do
      post oc_requests_url, params: { oc_request: { aceptado: @oc_request.aceptado, cantidad: @oc_request.cantidad, despachado: @oc_request.despachado, por_responder: @oc_request.por_responder, sftp_order_id: @oc_request.sftp_order_id, sku: @oc_request.sku } }
    end

    assert_redirected_to oc_request_url(OcRequest.last)
  end

  test "should show oc_request" do
    get oc_request_url(@oc_request)
    assert_response :success
  end

  test "should get edit" do
    get edit_oc_request_url(@oc_request)
    assert_response :success
  end

  test "should update oc_request" do
    patch oc_request_url(@oc_request), params: { oc_request: { aceptado: @oc_request.aceptado, cantidad: @oc_request.cantidad, despachado: @oc_request.despachado, por_responder: @oc_request.por_responder, sftp_order_id: @oc_request.sftp_order_id, sku: @oc_request.sku } }
    assert_redirected_to oc_request_url(@oc_request)
  end

  test "should destroy oc_request" do
    assert_difference('OcRequest.count', -1) do
      delete oc_request_url(@oc_request)
    end

    assert_redirected_to oc_requests_url
  end
end
