//
//  LocalizationService.swift
//  ChefOS
//

import Foundation
import Combine
import SwiftUI

// MARK: - In-App Localization

final class LocalizationService: ObservableObject {
    @Published var language: String {
        didSet {
            UserDefaults.standard.set(language, forKey: "app_language")
        }
    }

    static let shared = LocalizationService()

    init() {
        self.language = UserDefaults.standard.string(forKey: "app_language") ?? "en"
    }

    func t(_ key: String) -> String {
        translations[language]?[key] ?? translations["en"]?[key] ?? key
    }

    // MARK: - Translations

    private let translations: [String: [String: String]] = [
        // ──────────────── English ────────────────
        "en": [
            // Tabs
            "tab.chat": "Chat",
            "tab.recipes": "Recipes",
            "tab.plan": "Plan",
            "tab.profile": "Profile",

            // Profile sections
            "profile.title": "Profile",
            "profile.personalInfo": "Personal Info",
            "profile.goals": "Goals",
            "profile.preferences": "Preferences",
            "profile.restrictions": "Restrictions",
            "profile.lifestyle": "Lifestyle",
            "profile.region": "Region",

            // Profile fields
            "profile.age": "Age",
            "profile.weight": "Weight (kg)",
            "profile.goal": "Goal",
            "profile.targetWeight": "Target weight (kg)",
            "profile.caloriesDay": "Calories / day",
            "profile.protein": "Protein (g)",
            "profile.diet": "Diet",
            "profile.cuisine": "Cuisine",
            "profile.likes": "Likes",
            "profile.dislikes": "Dislikes",
            "profile.allergies": "Allergies",
            "profile.conditions": "Conditions",
            "profile.cookingLevel": "Cooking level",
            "profile.cookingTime": "Cooking time",
            "profile.mealsDay": "Meals / day",
            "profile.country": "Country",
            "profile.currency": "Currency",
            "profile.language": "Language",
            "profile.security": "Security",
            "profile.signOut": "Sign out",
            "profile.autoSaved": "Auto-saved",

            // AI Summary
            "profile.aiTitle": "ChefOS understands you",
            "profile.aiSubtitle": "Based on your profile",

            // Tags
            "tags.addLikes": "Add likes…",
            "tags.addDislikes": "Add dislikes…",
            "tags.addAllergies": "Add allergies…",
            "tags.addConditions": "Add conditions…",

            // Fitness goals
            "goal.loseWeight": "Lose weight",
            "goal.maintain": "Maintain",
            "goal.gainMuscle": "Gain muscle",
            "goal.eatHealthy": "Eat healthy",

            // Diet types
            "diet.any": "Any",
            "diet.vegetarian": "Vegetarian",
            "diet.vegan": "Vegan",
            "diet.keto": "Keto",
            "diet.paleo": "Paleo",
            "diet.mediterranean": "Mediterranean",

            // Cuisine
            "cuisine.any": "Any",
            "cuisine.italian": "Italian",
            "cuisine.asian": "Asian",
            "cuisine.mexican": "Mexican",
            "cuisine.slavic": "Slavic",
            "cuisine.french": "French",
            "cuisine.american": "American",

            // Cooking level
            "cooking.beginner": "Beginner",
            "cooking.intermediate": "Intermediate",
            "cooking.advanced": "Advanced",
            "cooking.chef": "Chef",

            // Cooking time
            "time.quick": "Quick (< 15 min)",
            "time.medium": "Medium (15–30 min)",
            "time.long": "Long (30–60 min)",
            "time.any": "Any time",

            // Chat
            "chat.title": "ChefOS",
            "chat.placeholder": "Ask me anything about cooking…",
            "chat.send": "Send",

            // Onboarding
            "onboarding.welcome": "Welcome to ChefOS",
            "onboarding.signIn": "Sign In",
            "onboarding.signUp": "Sign Up",
            "onboarding.email": "Email",
            "onboarding.password": "Password",
            "onboarding.name": "Your name",
            "onboarding.restaurantName": "Restaurant name",
            "onboarding.passwordHint": "Min 8 characters, at least one letter and one number",
            "onboarding.noAccount": "Don't have an account?",
            "onboarding.haveAccount": "Already have an account?",
            "onboarding.continue": "Continue",
            "onboarding.done": "Done",

            // Recipes
            "recipes.title": "Recipes",
            "recipes.search": "Search recipes…",

            // Plan
            "plan.title": "Meal Plan",
        ],

        // ──────────────── Русский ────────────────
        "ru": [
            "tab.chat": "Чат",
            "tab.recipes": "Рецепты",
            "tab.plan": "План",
            "tab.profile": "Профиль",

            "profile.title": "Профиль",
            "profile.personalInfo": "Личные данные",
            "profile.goals": "Цели",
            "profile.preferences": "Предпочтения",
            "profile.restrictions": "Ограничения",
            "profile.lifestyle": "Образ жизни",
            "profile.region": "Регион",

            "profile.age": "Возраст",
            "profile.weight": "Вес (кг)",
            "profile.goal": "Цель",
            "profile.targetWeight": "Целевой вес (кг)",
            "profile.caloriesDay": "Калории / день",
            "profile.protein": "Белок (г)",
            "profile.diet": "Диета",
            "profile.cuisine": "Кухня",
            "profile.likes": "Нравится",
            "profile.dislikes": "Не нравится",
            "profile.allergies": "Аллергии",
            "profile.conditions": "Заболевания",
            "profile.cookingLevel": "Уровень готовки",
            "profile.cookingTime": "Время готовки",
            "profile.mealsDay": "Приёмов пищи / день",
            "profile.country": "Страна",
            "profile.currency": "Валюта",
            "profile.language": "Язык",
            "profile.security": "Безопасность",
            "profile.signOut": "Выйти",
            "profile.autoSaved": "Сохранено",

            "profile.aiTitle": "ChefOS понимает вас",
            "profile.aiSubtitle": "На основе вашего профиля",

            "tags.addLikes": "Добавить…",
            "tags.addDislikes": "Добавить…",
            "tags.addAllergies": "Добавить аллергию…",
            "tags.addConditions": "Добавить заболевание…",

            "goal.loseWeight": "Похудеть",
            "goal.maintain": "Поддерживать",
            "goal.gainMuscle": "Набрать мышцы",
            "goal.eatHealthy": "Питаться правильно",

            "diet.any": "Любая",
            "diet.vegetarian": "Вегетарианская",
            "diet.vegan": "Веганская",
            "diet.keto": "Кето",
            "diet.paleo": "Палео",
            "diet.mediterranean": "Средиземноморская",

            "cuisine.any": "Любая",
            "cuisine.italian": "Итальянская",
            "cuisine.asian": "Азиатская",
            "cuisine.mexican": "Мексиканская",
            "cuisine.slavic": "Славянская",
            "cuisine.french": "Французская",
            "cuisine.american": "Американская",

            "cooking.beginner": "Новичок",
            "cooking.intermediate": "Средний",
            "cooking.advanced": "Продвинутый",
            "cooking.chef": "Шеф-повар",

            "time.quick": "Быстро (< 15 мин)",
            "time.medium": "Средне (15–30 мин)",
            "time.long": "Долго (30–60 мин)",
            "time.any": "Любое время",

            "chat.title": "ChefOS",
            "chat.placeholder": "Спросите что угодно о готовке…",
            "chat.send": "Отправить",

            "onboarding.welcome": "Добро пожаловать в ChefOS",
            "onboarding.signIn": "Войти",
            "onboarding.signUp": "Регистрация",
            "onboarding.email": "Email",
            "onboarding.password": "Пароль",
            "onboarding.name": "Ваше имя",
            "onboarding.restaurantName": "Название ресторана",
            "onboarding.passwordHint": "Мин. 8 символов, хотя бы одна буква и цифра",
            "onboarding.noAccount": "Нет аккаунта?",
            "onboarding.haveAccount": "Уже есть аккаунт?",
            "onboarding.continue": "Продолжить",
            "onboarding.done": "Готово",

            "recipes.title": "Рецепты",
            "recipes.search": "Поиск рецептов…",

            "plan.title": "План питания",
        ],

        // ──────────────── Polski ────────────────
        "pl": [
            "tab.chat": "Czat",
            "tab.recipes": "Przepisy",
            "tab.plan": "Plan",
            "tab.profile": "Profil",

            "profile.title": "Profil",
            "profile.personalInfo": "Dane osobowe",
            "profile.goals": "Cele",
            "profile.preferences": "Preferencje",
            "profile.restrictions": "Ograniczenia",
            "profile.lifestyle": "Styl życia",
            "profile.region": "Region",

            "profile.age": "Wiek",
            "profile.weight": "Waga (kg)",
            "profile.goal": "Cel",
            "profile.targetWeight": "Docelowa waga (kg)",
            "profile.caloriesDay": "Kalorie / dzień",
            "profile.protein": "Białko (g)",
            "profile.diet": "Dieta",
            "profile.cuisine": "Kuchnia",
            "profile.likes": "Lubię",
            "profile.dislikes": "Nie lubię",
            "profile.allergies": "Alergie",
            "profile.conditions": "Schorzenia",
            "profile.cookingLevel": "Poziom gotowania",
            "profile.cookingTime": "Czas gotowania",
            "profile.mealsDay": "Posiłków / dzień",
            "profile.country": "Kraj",
            "profile.currency": "Waluta",
            "profile.language": "Język",
            "profile.security": "Bezpieczeństwo",
            "profile.signOut": "Wyloguj",
            "profile.autoSaved": "Zapisano",

            "profile.aiTitle": "ChefOS rozumie Cię",
            "profile.aiSubtitle": "Na podstawie Twojego profilu",

            "tags.addLikes": "Dodaj…",
            "tags.addDislikes": "Dodaj…",
            "tags.addAllergies": "Dodaj alergię…",
            "tags.addConditions": "Dodaj schorzenie…",

            "goal.loseWeight": "Schudnąć",
            "goal.maintain": "Utrzymać wagę",
            "goal.gainMuscle": "Zbudować mięśnie",
            "goal.eatHealthy": "Zdrowo jeść",

            "diet.any": "Dowolna",
            "diet.vegetarian": "Wegetariańska",
            "diet.vegan": "Wegańska",
            "diet.keto": "Keto",
            "diet.paleo": "Paleo",
            "diet.mediterranean": "Śródziemnomorska",

            "cuisine.any": "Dowolna",
            "cuisine.italian": "Włoska",
            "cuisine.asian": "Azjatycka",
            "cuisine.mexican": "Meksykańska",
            "cuisine.slavic": "Słowiańska",
            "cuisine.french": "Francuska",
            "cuisine.american": "Amerykańska",

            "cooking.beginner": "Początkujący",
            "cooking.intermediate": "Średniozaawansowany",
            "cooking.advanced": "Zaawansowany",
            "cooking.chef": "Szef kuchni",

            "time.quick": "Szybko (< 15 min)",
            "time.medium": "Średnio (15–30 min)",
            "time.long": "Długo (30–60 min)",
            "time.any": "Dowolny czas",

            "chat.title": "ChefOS",
            "chat.placeholder": "Zapytaj o gotowanie…",
            "chat.send": "Wyślij",

            "onboarding.welcome": "Witaj w ChefOS",
            "onboarding.signIn": "Zaloguj się",
            "onboarding.signUp": "Zarejestruj się",
            "onboarding.email": "Email",
            "onboarding.password": "Hasło",
            "onboarding.name": "Twoje imię",
            "onboarding.restaurantName": "Nazwa restauracji",
            "onboarding.passwordHint": "Min. 8 znaków, co najmniej jedna litera i cyfra",
            "onboarding.noAccount": "Nie masz konta?",
            "onboarding.haveAccount": "Masz już konto?",
            "onboarding.continue": "Kontynuuj",
            "onboarding.done": "Gotowe",

            "recipes.title": "Przepisy",
            "recipes.search": "Szukaj przepisów…",

            "plan.title": "Plan posiłków",
        ],

        // ──────────────── Українська ────────────────
        "uk": [
            "tab.chat": "Чат",
            "tab.recipes": "Рецепти",
            "tab.plan": "План",
            "tab.profile": "Профіль",

            "profile.title": "Профіль",
            "profile.personalInfo": "Особисті дані",
            "profile.goals": "Цілі",
            "profile.preferences": "Вподобання",
            "profile.restrictions": "Обмеження",
            "profile.lifestyle": "Спосіб життя",
            "profile.region": "Регіон",

            "profile.age": "Вік",
            "profile.weight": "Вага (кг)",
            "profile.goal": "Ціль",
            "profile.targetWeight": "Цільова вага (кг)",
            "profile.caloriesDay": "Калорії / день",
            "profile.protein": "Білок (г)",
            "profile.diet": "Дієта",
            "profile.cuisine": "Кухня",
            "profile.likes": "Подобається",
            "profile.dislikes": "Не подобається",
            "profile.allergies": "Алергії",
            "profile.conditions": "Захворювання",
            "profile.cookingLevel": "Рівень готування",
            "profile.cookingTime": "Час готування",
            "profile.mealsDay": "Прийомів їжі / день",
            "profile.country": "Країна",
            "profile.currency": "Валюта",
            "profile.language": "Мова",
            "profile.security": "Безпека",
            "profile.signOut": "Вийти",
            "profile.autoSaved": "Збережено",

            "profile.aiTitle": "ChefOS розуміє вас",
            "profile.aiSubtitle": "На основі вашого профілю",

            "tags.addLikes": "Додати…",
            "tags.addDislikes": "Додати…",
            "tags.addAllergies": "Додати алергію…",
            "tags.addConditions": "Додати захворювання…",

            "goal.loseWeight": "Схуднути",
            "goal.maintain": "Підтримувати",
            "goal.gainMuscle": "Набрати м'язи",
            "goal.eatHealthy": "Їсти здорово",

            "diet.any": "Будь-яка",
            "diet.vegetarian": "Вегетаріанська",
            "diet.vegan": "Веганська",
            "diet.keto": "Кето",
            "diet.paleo": "Палео",
            "diet.mediterranean": "Середземноморська",

            "cuisine.any": "Будь-яка",
            "cuisine.italian": "Італійська",
            "cuisine.asian": "Азіатська",
            "cuisine.mexican": "Мексиканська",
            "cuisine.slavic": "Слов'янська",
            "cuisine.french": "Французька",
            "cuisine.american": "Американська",

            "cooking.beginner": "Початківець",
            "cooking.intermediate": "Середній",
            "cooking.advanced": "Просунутий",
            "cooking.chef": "Шеф-кухар",

            "time.quick": "Швидко (< 15 хв)",
            "time.medium": "Середньо (15–30 хв)",
            "time.long": "Довго (30–60 хв)",
            "time.any": "Будь-який час",

            "chat.title": "ChefOS",
            "chat.placeholder": "Запитайте будь-що про готування…",
            "chat.send": "Надіслати",

            "onboarding.welcome": "Ласкаво просимо до ChefOS",
            "onboarding.signIn": "Увійти",
            "onboarding.signUp": "Реєстрація",
            "onboarding.email": "Email",
            "onboarding.password": "Пароль",
            "onboarding.name": "Ваше ім'я",
            "onboarding.restaurantName": "Назва ресторану",
            "onboarding.passwordHint": "Мін. 8 символів, хоча б одна літера і цифра",
            "onboarding.noAccount": "Немає акаунту?",
            "onboarding.haveAccount": "Вже є акаунт?",
            "onboarding.continue": "Продовжити",
            "onboarding.done": "Готово",

            "recipes.title": "Рецепти",
            "recipes.search": "Пошук рецептів…",

            "plan.title": "План харчування",
        ],
    ]
}
