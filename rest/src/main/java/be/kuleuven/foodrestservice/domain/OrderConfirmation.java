package be.kuleuven.foodrestservice.domain;

import java.time.LocalDateTime;
import java.util.Objects;

public class OrderConfirmation {

    private String confirmationId;
    private String orderId;
    private LocalDateTime orderTime;
    private LocalDateTime estimatedDeliveryTime;
    private Double totalPrice;
    private String status;
    private String deliveryAddress;

    public OrderConfirmation() {
    }

    public OrderConfirmation(String confirmationId, String orderId, LocalDateTime orderTime,
                           LocalDateTime estimatedDeliveryTime, Double totalPrice, 
                           String status, String deliveryAddress) {
        this.confirmationId = confirmationId;
        this.orderId = orderId;
        this.orderTime = orderTime;
        this.estimatedDeliveryTime = estimatedDeliveryTime;
        this.totalPrice = totalPrice;
        this.status = status;
        this.deliveryAddress = deliveryAddress;
    }

    public String getConfirmationId() {
        return confirmationId;
    }

    public void setConfirmationId(String confirmationId) {
        this.confirmationId = confirmationId;
    }

    public String getOrderId() {
        return orderId;
    }

    public void setOrderId(String orderId) {
        this.orderId = orderId;
    }

    public LocalDateTime getOrderTime() {
        return orderTime;
    }

    public void setOrderTime(LocalDateTime orderTime) {
        this.orderTime = orderTime;
    }

    public LocalDateTime getEstimatedDeliveryTime() {
        return estimatedDeliveryTime;
    }

    public void setEstimatedDeliveryTime(LocalDateTime estimatedDeliveryTime) {
        this.estimatedDeliveryTime = estimatedDeliveryTime;
    }

    public Double getTotalPrice() {
        return totalPrice;
    }

    public void setTotalPrice(Double totalPrice) {
        this.totalPrice = totalPrice;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public String getDeliveryAddress() {
        return deliveryAddress;
    }

    public void setDeliveryAddress(String deliveryAddress) {
        this.deliveryAddress = deliveryAddress;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        OrderConfirmation that = (OrderConfirmation) o;
        return Objects.equals(confirmationId, that.confirmationId);
    }

    @Override
    public int hashCode() {
        return Objects.hash(confirmationId);
    }

    @Override
    public String toString() {
        return "OrderConfirmation{" +
                "confirmationId='" + confirmationId + '\'' +
                ", orderId='" + orderId + '\'' +
                ", orderTime=" + orderTime +
                ", estimatedDeliveryTime=" + estimatedDeliveryTime +
                ", totalPrice=" + totalPrice +
                ", status='" + status + '\'' +
                ", deliveryAddress='" + deliveryAddress + '\'' +
                '}';
    }
}
