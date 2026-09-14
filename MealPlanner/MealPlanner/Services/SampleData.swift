import Foundation

/// Appendix A sample data, used by `MealStore.addSampleMeals()` and `PreviewContainer`.
enum SampleData {
    struct IngredientInfo {
        let name: String
        let unit: IngredientUnit
        let category: ShoppingCategory
    }

    struct RecipeLine {
        let ingredientName: String
        let quantity: Double?
        let unit: IngredientUnit
        let note: String

        init(_ ingredientName: String, _ quantity: Double?, _ unit: IngredientUnit, note: String = "") {
            self.ingredientName = ingredientName
            self.quantity = quantity
            self.unit = unit
            self.note = note
        }
    }

    struct MealInfo {
        let name: String
        let types: Set<MealType>
        let servings: Int
        let totalMinutes: Int?
        let notes: String
        let lines: [RecipeLine]
        let steps: [String]

        init(
            name: String,
            types: Set<MealType>,
            servings: Int,
            totalMinutes: Int?,
            notes: String = "",
            lines: [RecipeLine] = [],
            steps: [String] = []
        ) {
            self.name = name
            self.types = types
            self.servings = servings
            self.totalMinutes = totalMinutes
            self.notes = notes
            self.lines = lines
            self.steps = steps
        }
    }

    // MARK: A.1 Ingredient library (28)

    static let ingredients: [IngredientInfo] = [
        IngredientInfo(name: "Rolled oats", unit: .g, category: .pantry),
        IngredientInfo(name: "Milk", unit: .ml, category: .dairyEggs),
        IngredientInfo(name: "Greek yoghurt", unit: .tbsp, category: .dairyEggs),
        IngredientInfo(name: "Honey", unit: .tsp, category: .pantry),
        IngredientInfo(name: "Blueberries", unit: .handful, category: .produce),
        IngredientInfo(name: "Eggs", unit: .item, category: .dairyEggs),
        IngredientInfo(name: "Butter", unit: .g, category: .dairyEggs),
        IngredientInfo(name: "Bread", unit: .slice, category: .bakery),
        IngredientInfo(name: "Salt", unit: .pinch, category: .pantry),
        IngredientInfo(name: "Black pepper", unit: .pinch, category: .pantry),
        IngredientInfo(name: "Tortilla wraps", unit: .item, category: .bakery),
        IngredientInfo(name: "Chicken breast", unit: .g, category: .meatFish),
        IngredientInfo(name: "Romaine lettuce", unit: .item, category: .produce),
        IngredientInfo(name: "Parmesan", unit: .g, category: .dairyEggs),
        IngredientInfo(name: "Caesar dressing", unit: .tbsp, category: .pantry),
        IngredientInfo(name: "Onion", unit: .item, category: .produce),
        IngredientInfo(name: "Garlic", unit: .clove, category: .produce),
        IngredientInfo(name: "Chopped tomatoes", unit: .tin, category: .pantry),
        IngredientInfo(name: "Vegetable stock", unit: .ml, category: .pantry),
        IngredientInfo(name: "Olive oil", unit: .tbsp, category: .pantry),
        IngredientInfo(name: "Beef mince", unit: .g, category: .meatFish),
        IngredientInfo(name: "Spaghetti", unit: .g, category: .pantry),
        IngredientInfo(name: "Peppers", unit: .item, category: .produce),
        IngredientInfo(name: "Fajita seasoning", unit: .pack, category: .pantry),
        IngredientInfo(name: "Soured cream", unit: .ml, category: .dairyEggs),
        IngredientInfo(name: "Kidney beans", unit: .tin, category: .pantry),
        IngredientInfo(name: "Chilli powder", unit: .tsp, category: .pantry),
        IngredientInfo(name: "Rice", unit: .g, category: .pantry),
    ]

    static func ingredientInfo(named name: String) -> IngredientInfo {
        ingredients.first { $0.name == name } ?? IngredientInfo(name: name, unit: .item, category: .other)
    }

    // MARK: A.2 Meals (8)

    static let meals: [MealInfo] = [
        MealInfo(
            name: "Overnight oats",
            types: [.breakfast],
            servings: 1,
            totalMinutes: 5,
            lines: [
                RecipeLine("Rolled oats", 50, .g),
                RecipeLine("Milk", 150, .ml),
                RecipeLine("Greek yoghurt", 2, .tbsp),
                RecipeLine("Honey", 1, .tsp),
                RecipeLine("Blueberries", 1, .handful),
            ],
            steps: [
                "Mix the oats, milk, yoghurt and honey in a jar.",
                "Cover and refrigerate overnight.",
                "Top with blueberries before serving.",
            ]
        ),
        MealInfo(
            name: "Scrambled eggs on toast",
            types: [.breakfast],
            servings: 1,
            totalMinutes: 10,
            lines: [
                RecipeLine("Eggs", 3, .item),
                RecipeLine("Butter", 10, .g),
                RecipeLine("Bread", 2, .slice),
                RecipeLine("Salt", nil, .pinch),
                RecipeLine("Black pepper", nil, .pinch),
            ],
            steps: [
                "Whisk the eggs with a pinch of salt and pepper.",
                "Melt the butter over a low heat.",
                "Stir the eggs gently until just set.",
                "Serve on hot buttered toast.",
            ]
        ),
        MealInfo(
            name: "Chicken Caesar wrap",
            types: [.lunch],
            servings: 2,
            totalMinutes: 15,
            lines: [
                RecipeLine("Tortilla wraps", 2, .item),
                RecipeLine("Chicken breast", 150, .g, note: "cooked, sliced"),
                RecipeLine("Romaine lettuce", 1, .item),
                RecipeLine("Parmesan", 20, .g, note: "grated"),
                RecipeLine("Caesar dressing", 2, .tbsp),
            ],
            steps: [
                "Toss the lettuce with the dressing.",
                "Fill the wraps with lettuce, chicken and parmesan.",
                "Roll up tightly and slice in half.",
            ]
        ),
        MealInfo(
            name: "Tomato soup",
            types: [.lunch, .dinner],
            servings: 4,
            totalMinutes: 30,
            lines: [
                RecipeLine("Onion", 1, .item, note: "chopped"),
                RecipeLine("Garlic", 2, .clove),
                RecipeLine("Chopped tomatoes", 2, .tin),
                RecipeLine("Vegetable stock", 500, .ml),
                RecipeLine("Olive oil", 1, .tbsp),
            ],
            steps: [
                "Soften the onion and garlic in the oil for 5 minutes.",
                "Add the tomatoes and stock and simmer for 15 minutes.",
                "Blend until smooth and season to taste.",
            ]
        ),
        MealInfo(
            name: "Spaghetti bolognese",
            types: [.dinner],
            servings: 4,
            totalMinutes: 45,
            lines: [
                RecipeLine("Beef mince", 500, .g),
                RecipeLine("Onion", 1, .item, note: "finely chopped"),
                RecipeLine("Garlic", 2, .clove),
                RecipeLine("Chopped tomatoes", 1, .tin),
                RecipeLine("Spaghetti", 300, .g),
                RecipeLine("Olive oil", 1, .tbsp),
            ],
            steps: [
                "Brown the mince in the oil.",
                "Add the onion and garlic and cook for 5 minutes.",
                "Add the tomatoes and simmer for 25 minutes.",
                "Cook the spaghetti and serve with the sauce.",
            ]
        ),
        MealInfo(
            name: "Chicken fajitas",
            types: [.dinner],
            servings: 4,
            totalMinutes: 30,
            lines: [
                RecipeLine("Chicken breast", 400, .g, note: "sliced"),
                RecipeLine("Peppers", 2, .item, note: "sliced"),
                RecipeLine("Onion", 1, .item, note: "sliced"),
                RecipeLine("Fajita seasoning", 1, .pack),
                RecipeLine("Tortilla wraps", 8, .item),
                RecipeLine("Soured cream", 150, .ml),
            ],
            steps: [
                "Coat the chicken and vegetables in the seasoning.",
                "Fry over a high heat for 10–12 minutes.",
                "Warm the wraps and serve with soured cream.",
            ]
        ),
        MealInfo(
            name: "Veggie chilli",
            types: [.dinner],
            servings: 4,
            totalMinutes: 40,
            lines: [
                RecipeLine("Onion", 1, .item),
                RecipeLine("Garlic", 3, .clove),
                RecipeLine("Kidney beans", 2, .tin, note: "drained"),
                RecipeLine("Chopped tomatoes", 1, .tin),
                RecipeLine("Chilli powder", 2, .tsp),
                RecipeLine("Rice", 250, .g),
            ],
            steps: [
                "Soften the onion and garlic.",
                "Add the chilli powder, beans and tomatoes and simmer for 25 minutes.",
                "Serve with rice.",
            ]
        ),
        MealInfo(
            name: "Eat out",
            types: [.lunch, .dinner],
            servings: 1,
            totalMinutes: nil,
            notes: "Night off from cooking."
        ),
    ]
}
