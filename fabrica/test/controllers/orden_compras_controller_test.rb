require 'test_helper'

class OrdenComprasControllerTest < ActionDispatch::IntegrationTest
  setup do
    @orden_compra = orden_compras(:one)
  end

  test "should get index" do
    get orden_compras_url
    assert_response :success
  end

  test "should get new" do
    get new_orden_compra_url
    assert_response :success
  end

  test "should create orden_compra" do
    assert_difference('OrdenCompra.count') do
      post orden_compras_url, params: { orden_compra: { _id: @orden_compra._id, anulacion: @orden_compra.anulacion, canal: @orden_compra.canal, cantidad: @orden_compra.cantidad, cantidadDespachada: @orden_compra.cantidadDespachada, cliente: @orden_compra.cliente, created_at: @orden_compra.created_at, estado: @orden_compra.estado, fechaEntrega: @orden_compra.fechaEntrega, notas: @orden_compra.notas, precioUnitario: @orden_compra.precioUnitario, proveedor: @orden_compra.proveedor, rechazo: @orden_compra.rechazo, sku: @orden_compra.sku, updated_at: @orden_compra.updated_at, urlNotificacion: @orden_compra.urlNotificacion } }
    end

    assert_redirected_to orden_compra_url(OrdenCompra.last)
  end

  test "should show orden_compra" do
    get orden_compra_url(@orden_compra)
    assert_response :success
  end

  test "should get edit" do
    get edit_orden_compra_url(@orden_compra)
    assert_response :success
  end

  test "should update orden_compra" do
    patch orden_compra_url(@orden_compra), params: { orden_compra: { _id: @orden_compra._id, anulacion: @orden_compra.anulacion, canal: @orden_compra.canal, cantidad: @orden_compra.cantidad, cantidadDespachada: @orden_compra.cantidadDespachada, cliente: @orden_compra.cliente, created_at: @orden_compra.created_at, estado: @orden_compra.estado, fechaEntrega: @orden_compra.fechaEntrega, notas: @orden_compra.notas, precioUnitario: @orden_compra.precioUnitario, proveedor: @orden_compra.proveedor, rechazo: @orden_compra.rechazo, sku: @orden_compra.sku, updated_at: @orden_compra.updated_at, urlNotificacion: @orden_compra.urlNotificacion } }
    assert_redirected_to orden_compra_url(@orden_compra)
  end

  test "should destroy orden_compra" do
    assert_difference('OrdenCompra.count', -1) do
      delete orden_compra_url(@orden_compra)
    end

    assert_redirected_to orden_compras_url
  end
end
