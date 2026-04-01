package be.kuleuven.foodrestservice.domain;

import java.util.List;
import java.util.Objects;

public class Order {

    private String orderId;
    private List<String> mealIds;
    private String deliveryAddress;
    private String customerName;

    public Order() {
    }

    public Order(String orderId, List<String> mealIds, String deliveryAddress, String customerName) {
        this.orderId = orderId;
        this.mealIds = mealIds;
        this.deliveryAddress = deliveryAddress;
        this.customerName = customerName;
    }

    public String getOrderId() {
        return orderId;
    }

    public void setOrderId(String orderId) {
        this.orderId = orderId;
    }

    public List<String> getMealIds() {
        return mealIds;
    }

    public void setMealIds(List<String> mealIds) {
        this.mealIds = mealIds;
    }

    public String getDeliveryAddress() {
        return deliveryAddress;
    }

    public void setDeliveryAddress(String deliveryAddress) {
        this.deliveryAddress = deliveryAddress;
    }

    public String getCustomerName() {
        return customerName;
    }

    public void setCustomerName(String customerName) {
        this.customerName = customerName;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        Order order = (Order) o;
        return Objects.equals(orderId, order.orderId);
    }

    @Override
    public int hashCode() {
        return Objects.hash(orderId);
    }

    @Override
    public String toString() {
        return "Order{" +
                "orderId='" + orderId + '\'' +
                ", mealIds=" + mealIds +
                ", deliveryAddress='" + deliveryAddress + '\'' +
                ", customerName='" + customerName + '\'' +
                '}';
    }
}
