require 'test_helper'

class TransferenciaControllerTest < ActionDispatch::IntegrationTest
  setup do
    @transferencium = transferencia(:one)
  end

  test "should get index" do
    get transferencia_url
    assert_response :success
  end

  test "should get new" do
    get new_transferencium_url
    assert_response :success
  end

  test "should create transferencium" do
    assert_difference('Transferencium.count') do
      post transferencia_url, params: { transferencium: { destino: @transferencium.destino, idtransferencia: @transferencium.idtransferencia, integer: @transferencium.integer, monto: @transferencium.monto, origen: @transferencium.origen, originator_id: @transferencium.originator_id, originator_type: @transferencium.originator_type, string: @transferencium.string, string: @transferencium.string, string: @transferencium.string } }
    end

    assert_redirected_to transferencium_url(Transferencium.last)
  end

  test "should show transferencium" do
    get transferencium_url(@transferencium)
    assert_response :success
  end

  test "should get edit" do
    get edit_transferencium_url(@transferencium)
    assert_response :success
  end

  test "should update transferencium" do
    patch transferencium_url(@transferencium), params: { transferencium: { destino: @transferencium.destino, idtransferencia: @transferencium.idtransferencia, integer: @transferencium.integer, monto: @transferencium.monto, origen: @transferencium.origen, originator_id: @transferencium.originator_id, originator_type: @transferencium.originator_type, string: @transferencium.string, string: @transferencium.string, string: @transferencium.string } }
    assert_redirected_to transferencium_url(@transferencium)
  end

  test "should destroy transferencium" do
    assert_difference('Transferencium.count', -1) do
      delete transferencium_url(@transferencium)
    end

    assert_redirected_to transferencia_url
  end
end
