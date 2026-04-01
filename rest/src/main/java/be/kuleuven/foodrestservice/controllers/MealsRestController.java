package be.kuleuven.foodrestservice.controllers;

import be.kuleuven.foodrestservice.domain.Meal;
import be.kuleuven.foodrestservice.domain.MealsRepository;
import be.kuleuven.foodrestservice.domain.Order;
import be.kuleuven.foodrestservice.domain.OrderConfirmation;
import be.kuleuven.foodrestservice.exceptions.MealNotFoundException;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.hateoas.CollectionModel;
import org.springframework.hateoas.EntityModel;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.*;

import static org.springframework.hateoas.server.mvc.WebMvcLinkBuilder.*;

@RestController
public class MealsRestController {

    private final MealsRepository mealsRepository;

    @Autowired
    MealsRestController(MealsRepository mealsRepository) {
        this.mealsRepository = mealsRepository;
    }

    @GetMapping("/rest/meals/{id}")
    ResponseEntity<EntityModel<Meal>> getMealById(@PathVariable String id) {
        Meal meal = mealsRepository.findMeal(id).orElseThrow(() -> new MealNotFoundException(id));

        return ResponseEntity.ok(mealToEntityModel(id, meal));
    }

    @GetMapping("/rest/meals")
    ResponseEntity<CollectionModel<EntityModel<Meal>>> getMeals() {
        Collection<Meal> meals = mealsRepository.getAllMeal();

        List<EntityModel<Meal>> mealEntityModels = new ArrayList<>();
        for (Meal m : meals) {
            EntityModel<Meal> em = mealToEntityModel(m.getId(), m);
            mealEntityModels.add(em);
        }
        return ResponseEntity.ok(CollectionModel.of(mealEntityModels,
                linkTo(methodOn(MealsRestController.class).getMeals()).withSelfRel()));
    }

    @PostMapping("/rest/meals/{id}")
    ResponseEntity<EntityModel<Meal>> addMeal(@PathVariable String id, @RequestBody Meal meal) {
        mealsRepository.addMeal(meal);
        return ResponseEntity.status(HttpStatus.CREATED).body(mealToEntityModel(id, meal));
    }

    @DeleteMapping("/rest/meals/{id}")
    ResponseEntity<EntityModel<Meal>> deleteMeal(@PathVariable String id) {
        Meal meal = mealsRepository.findMeal(id).orElseThrow(() -> new MealNotFoundException(id));
        mealsRepository.deleteMeal(id);
        return ResponseEntity.ok(mealToEntityModel(id, meal));
    }

    @GetMapping("/rest/cheapest")
    ResponseEntity<EntityModel<Meal>> getCheapestMeal() {
        return ResponseEntity.ok(mealToEntityModel(null, mealsRepository.getCheapestMeal()));
    }

    @GetMapping("/rest/largest")
    ResponseEntity<EntityModel<Meal>> getLargestMeal() {
        return ResponseEntity.ok(mealToEntityModel(null, mealsRepository.getLargestMeal()));
    }

    @PostMapping("/rest/order")
    ResponseEntity<EntityModel<OrderConfirmation>> addOrder(@RequestBody Order order) {
        OrderConfirmation confirmation = processOrder(order);
        return ResponseEntity.status(HttpStatus.CREATED).body(orderConfirmationToEntityModel(confirmation));
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

    private EntityModel<Meal> mealToEntityModel(String id, Meal meal) {
        return EntityModel.of(meal,
                linkTo(methodOn(MealsRestController.class).getMealById(id)).withSelfRel(),
                linkTo(methodOn(MealsRestController.class).getMeals()).withRel("rest/meals"));
    }

    private EntityModel<OrderConfirmation> orderConfirmationToEntityModel(OrderConfirmation confirmation) {
        return EntityModel.of(confirmation,
                linkTo(methodOn(MealsRestController.class).addOrder(null)).withRel("rest/order"),
                linkTo(methodOn(MealsRestController.class).getMeals()).withRel("rest/meals"));
    }

}
