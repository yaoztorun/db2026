package be.kuleuven.foodrestservice.controllers;

import be.kuleuven.foodrestservice.domain.Meal;
import be.kuleuven.foodrestservice.domain.MealsRepository;
import be.kuleuven.foodrestservice.domain.Order;
import be.kuleuven.foodrestservice.domain.OrderConfirmation;
import be.kuleuven.foodrestservice.exceptions.MealNotFoundException;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.Collection;
import java.util.Optional;
import java.util.UUID;

@RestController
public class MealsRestRpcStyleController {

    private final MealsRepository mealsRepository;

    @Autowired
    MealsRestRpcStyleController(MealsRepository mealsRepository) {
        this.mealsRepository = mealsRepository;
    }

    @GetMapping("/restrpc/meals/{id}")
    ResponseEntity<Meal> getMealById(@PathVariable String id) {
        Optional<Meal> meal = mealsRepository.findMeal(id);

        return ResponseEntity.ok(meal.orElseThrow(() -> new MealNotFoundException(id)));
    }

    @PostMapping("/restrpc/meals/{id}")
    Meal addMeal(@PathVariable String id, @RequestBody Meal meal) {
        mealsRepository.addMeal(meal);
        return meal;
    }

    @DeleteMapping("/restrpc/meals/{id}")
    Meal deleteMeal(@PathVariable String id) {
        Meal meal = mealsRepository.findMeal(id).orElseThrow(() -> new MealNotFoundException(id));
        mealsRepository.deleteMeal(id);
        return meal;
    }

    @GetMapping("/restrpc/meals")
    ResponseEntity<Collection<Meal>> getMeals() {
        return ResponseEntity.ok(mealsRepository.getAllMeal());
    }

    @GetMapping("/restrpc/cheapest")
    ResponseEntity<Meal> getCheapestMeal() {
        return ResponseEntity.ok(mealsRepository.getCheapestMeal());
    }

    @GetMapping("/restrpc/largest")
    ResponseEntity<Meal> getLargestMeal() {
        return ResponseEntity.ok(mealsRepository.getLargestMeal());
    }

    @PostMapping("/restrpc/order")
    ResponseEntity<OrderConfirmation> addOrder(@RequestBody Order order) {
        OrderConfirmation confirmation = processOrder(order);
        return ResponseEntity.status(HttpStatus.CREATED).body(confirmation);
    }

    private OrderConfirmation processOrder(Order order) {
        // Calculate total price from meals
        double totalPrice = 0.0;
        for (String mealId : order.getMealIds()) {
            Optional<Meal> meal = mealsRepository.findMeal(mealId);
            if (meal.isPresent()) {
                totalPrice += meal.get().getPrice();
            } else {
                throw new MealNotFoundException(mealId);
            }
        }

        // Create confirmation
        String confirmationId = UUID.randomUUID().toString();
        LocalDateTime orderTime = LocalDateTime.now();
        LocalDateTime estimatedDelivery = orderTime.plusMinutes(45); // 45 min delivery time

        return new OrderConfirmation(
                confirmationId,
                order.getOrderId(),
                orderTime,
                estimatedDelivery,
                totalPrice,
                "CONFIRMED",
                order.getDeliveryAddress()
        );
    }
}
