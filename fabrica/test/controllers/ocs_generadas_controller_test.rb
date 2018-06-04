require 'test_helper'

class OcsGeneradasControllerTest < ActionDispatch::IntegrationTest
  setup do
    @ocs_generada = ocs_generadas(:one)
  end

  test "should get index" do
    get ocs_generadas_url
    assert_response :success
  end

  test "should get new" do
    get new_ocs_generada_url
    assert_response :success
  end

  test "should create ocs_generada" do
    assert_difference('OcsGenerada.count') do
      post ocs_generadas_url, params: { ocs_generada: { canal: @ocs_generada.canal, cantidad: @ocs_generada.cantidad, cliente: @ocs_generada.cliente, fechaEntrega: @ocs_generada.fechaEntrega, grupo: @ocs_generada.grupo, notas: @ocs_generada.notas, oc_id: @ocs_generada.oc_id, oc_request_id: @ocs_generada.oc_request_id, precioUnitario: @ocs_generada.precioUnitario, proveedor: @ocs_generada.proveedor, sku: @ocs_generada.sku, urlNotificacion: @ocs_generada.urlNotificacion } }
    end

    assert_redirected_to ocs_generada_url(OcsGenerada.last)
  end

  test "should show ocs_generada" do
    get ocs_generada_url(@ocs_generada)
    assert_response :success
  end

  test "should get edit" do
    get edit_ocs_generada_url(@ocs_generada)
    assert_response :success
  end

  test "should update ocs_generada" do
    patch ocs_generada_url(@ocs_generada), params: { ocs_generada: { canal: @ocs_generada.canal, cantidad: @ocs_generada.cantidad, cliente: @ocs_generada.cliente, fechaEntrega: @ocs_generada.fechaEntrega, grupo: @ocs_generada.grupo, notas: @ocs_generada.notas, oc_id: @ocs_generada.oc_id, oc_request_id: @ocs_generada.oc_request_id, precioUnitario: @ocs_generada.precioUnitario, proveedor: @ocs_generada.proveedor, sku: @ocs_generada.sku, urlNotificacion: @ocs_generada.urlNotificacion } }
    assert_redirected_to ocs_generada_url(@ocs_generada)
  end

  test "should destroy ocs_generada" do
    assert_difference('OcsGenerada.count', -1) do
      delete ocs_generada_url(@ocs_generada)
    end

    assert_redirected_to ocs_generadas_url
  end
end
