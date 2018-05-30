require 'test_helper'

class SftpOrdersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @sftp_order = sftp_orders(:one)
  end

  test "should get index" do
    get sftp_orders_url
    assert_response :success
  end

  test "should get new" do
    get new_sftp_order_url
    assert_response :success
  end

  test "should create sftp_order" do
    assert_difference('SftpOrder.count') do
      post sftp_orders_url, params: { sftp_order: { anulacion: @sftp_order.anulacion, canal: @sftp_order.canal, cantidad: @sftp_order.cantidad, cliente: @sftp_order.cliente, fechaEntrega: @sftp_order.fechaEntrega, myCantidadDespachada: @sftp_order.myCantidadDespachada, myEstado: @sftp_order.myEstado, notas: @sftp_order.notas, oc: @sftp_order.oc, precioUnitario: @sftp_order.precioUnitario, proveedor: @sftp_order.proveedor, rechazo: @sftp_order.rechazo, serverCantidadDespachada: @sftp_order.serverCantidadDespachada, serverEstado: @sftp_order.serverEstado, sku: @sftp_order.sku, urlNotificacion: @sftp_order.urlNotificacion } }
    end

    assert_redirected_to sftp_order_url(SftpOrder.last)
  end

  test "should show sftp_order" do
    get sftp_order_url(@sftp_order)
    assert_response :success
  end

  test "should get edit" do
    get edit_sftp_order_url(@sftp_order)
    assert_response :success
  end

  test "should update sftp_order" do
    patch sftp_order_url(@sftp_order), params: { sftp_order: { anulacion: @sftp_order.anulacion, canal: @sftp_order.canal, cantidad: @sftp_order.cantidad, cliente: @sftp_order.cliente, fechaEntrega: @sftp_order.fechaEntrega, myCantidadDespachada: @sftp_order.myCantidadDespachada, myEstado: @sftp_order.myEstado, notas: @sftp_order.notas, oc: @sftp_order.oc, precioUnitario: @sftp_order.precioUnitario, proveedor: @sftp_order.proveedor, rechazo: @sftp_order.rechazo, serverCantidadDespachada: @sftp_order.serverCantidadDespachada, serverEstado: @sftp_order.serverEstado, sku: @sftp_order.sku, urlNotificacion: @sftp_order.urlNotificacion } }
    assert_redirected_to sftp_order_url(@sftp_order)
  end

  test "should destroy sftp_order" do
    assert_difference('SftpOrder.count', -1) do
      delete sftp_order_url(@sftp_order)
    end

    assert_redirected_to sftp_orders_url
  end
end
