package com.example.springsoap;

import javax.annotation.PostConstruct;
import java.util.Comparator;
import java.util.Map;
import java.util.NoSuchElementException;
import java.math.BigDecimal;
import java.util.concurrent.ConcurrentHashMap;


import io.foodmenu.gt.webservice.*;


import org.springframework.stereotype.Component;
import org.springframework.util.Assert;

@Component
public class MealRepository {
    private final Map<String, Meal> meals = new ConcurrentHashMap<>();

    @PostConstruct
    public void initData() {

        Meal a = new Meal();
        a.setName("Steak");
        a.setDescription("Steak with fries");
        a.setMealtype(Mealtype.MEAT);
        a.setKcal(1100);
        a.setPrice(BigDecimal.valueOf(14));

        meals.put(a.getName(), a);

        Meal b = new Meal();
        b.setName("Portobello");
        b.setDescription("Portobello Mushroom Burger");
        b.setMealtype(Mealtype.VEGAN);
        b.setKcal(637);
        b.setPrice(BigDecimal.valueOf(12));

        meals.put(b.getName(), b);

        Meal c = new Meal();
        c.setName("Fish and Chips");
        c.setDescription("Fried fish with chips");
        c.setMealtype(Mealtype.FISH);
        c.setKcal(950);
        c.setPrice(BigDecimal.valueOf(10));

        meals.put(c.getName(), c);
    }

    public Meal findMeal(String name) {
        Assert.notNull(name, "The meal's code must not be null");
        return meals.get(name);
    }

    public Meal findBiggestMeal() {
        return meals.values().stream()
                .max(Comparator.comparing(Meal::getKcal))
                .orElseThrow(NoSuchElementException::new);
    }

    public Meal findCheapestMeal() {
        return meals.values().stream()
                .min(Comparator.comparing(Meal::getPrice))
                .orElseThrow(NoSuchElementException::new);
    }


}
