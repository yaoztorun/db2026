package com.example.springsoap;

import io.foodmenu.gt.webservice.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import javax.xml.datatype.DatatypeConfigurationException;
import javax.xml.datatype.DatatypeFactory;
import javax.xml.datatype.XMLGregorianCalendar;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;

@Component
public class OrderRepository {
    
    private final Map<String, OrderConfirmation> orders = new ConcurrentHashMap<>();
    private final AtomicLong orderCounter = new AtomicLong(1000);
    
    @Autowired
    private MealRepository mealRepository;
    
    public OrderConfirmation addOrder(Order order) {
        // Generate unique order ID
        String orderId = "ORD-" + orderCounter.incrementAndGet();
        
        // Create order confirmation
        OrderConfirmation confirmation = new OrderConfirmation();
        confirmation.setOrderId(orderId);
        confirmation.setCustomerName(order.getCustomerName());
        confirmation.setDeliveryAddress(order.getDeliveryAddress());
        confirmation.setStatus("CONFIRMED");
        confirmation.setEstimatedDeliveryTime("45-60 minutes");
        
        // Set order date to current time
        try {
            GregorianCalendar gcal = GregorianCalendar.from(LocalDateTime.now().atZone(ZoneId.systemDefault()));
            XMLGregorianCalendar xmlDate = DatatypeFactory.newInstance().newXMLGregorianCalendar(gcal);
            confirmation.setOrderDate(xmlDate);
        } catch (DatatypeConfigurationException e) {
            throw new RuntimeException("Error setting order date", e);
        }
        
        // Find meals and calculate total
        List<Meal> orderedMeals = new ArrayList<>();
        BigDecimal totalAmount = BigDecimal.ZERO;
        
        for (String mealName : order.getMealNames()) {
            Meal meal = mealRepository.findMeal(mealName);
            if (meal != null) {
                orderedMeals.add(meal);
                totalAmount = totalAmount.add(meal.getPrice());
            } else {
                throw new IllegalArgumentException("Meal not found: " + mealName);
            }
        }
        
        confirmation.getMeals().addAll(orderedMeals);
        confirmation.setTotalAmount(totalAmount);
        
        // Store the order
        orders.put(orderId, confirmation);
        
        return confirmation;
    }
    
    public OrderConfirmation findOrder(String orderId) {
        return orders.get(orderId);
    }
    
    public Collection<OrderConfirmation> getAllOrders() {
        return orders.values();
    }
}
