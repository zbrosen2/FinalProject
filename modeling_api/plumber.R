#
# This is a Plumber API. You can run the API by clicking
# the 'Run API' button above.
#
# Find out more about building APIs with Plumber here:
#
#    https://www.rplumber.io/
#

set.seed(123)
library(plumber)
library(tidyverse)
library(rsample)
library(caret)
library(yardstick)

diabetes <- read_csv("./data/diabetes_binary_health_indicators_BRFSS2015.csv")

# calculate mean (if numeric) or most prevalent class (if categorical)
mean_bmi <- mean(diabetes$BMI)

mode_age <- names(sort(table(diabetes$Age), decreasing = TRUE))[1]
mode_highBP <- names(sort(table(diabetes$HighBP), decreasing = TRUE))[1]
mode_highChol <- names(sort(table(diabetes$HighChol), decreasing = TRUE))[1]
mode_smoker <- names(sort(table(diabetes$Smoker), decreasing = TRUE))[1]
mode_physActivity <- names(sort(table(diabetes$PhysActivity), decreasing = TRUE))[1]

# convert categorical variables to factors
diabetes <- diabetes |>
  mutate(Diabetes_binary = factor(Diabetes_binary, labels = c("N", "Y")),
         HighBP = factor(HighBP),
         HighChol = factor(HighChol),
         Smoker = factor(Smoker),
         PhysActivity = factor(PhysActivity),
         Age = factor(Age, ordered = TRUE)
  )

# split data into train/test (70/30)
data_split <- initial_split(diabetes, prop = 0.7)
train <- training(data_split)
test <- testing(data_split)

# fit best model from modeling file (LR_3 with alpha = 0.5, lambda = 0.001)
model_final <- train(Diabetes_binary ~ HighBP + HighChol + Smoker 
                    + PhysActivity + Age*BMI,
                    data = train,
                    metric = "logLoss",
                    preProcess = c("center", "scale"),
                    trControl = trainControl(method = "none", classProbs = TRUE),
                    method = "glmnet",
                    family = "binomial",
                    tuneGrid = expand.grid(alpha = c(0.5), lambda = c(0.001))
)

#* @apiTitle Model API
#* @apiDescription Model API allows you to predict using the final model.

#* Predict using final model
#* @param HighBP The HighBP predictor 
#* @param HighChol The HighChol predictor
#* @param Smoker The Smoker predictor
#* @param PhysActivity The PhysActivity predictor
#* @param Age The Age predictor
#* @param BMI The BMI predictor
#* @get /pred
function(HighBP = mode_highBP, HighChol = mode_highChol, Smoker = mode_smoker, 
         PhysActivity = mode_physActivity, Age = mode_age, BMI = mean_bmi) {
    # convert default values to factors (categorical) and ensure numeric (numeric)
    pred_data <- data.frame(
      HighBP = factor(HighBP, levels = levels(diabetes$HighBP)),
      HighChol = factor(HighChol, levels = levels(diabetes$HighChol)),
      Smoker = factor(Smoker, levels = levels(diabetes$Smoker)),
      PhysActivity = factor(PhysActivity, levels = levels(diabetes$PhysActivity)),
      Age = factor(Age, levels = levels(diabetes$Age), ordered = TRUE),
      BMI = as.numeric(BMI)
    )
    
    # predict using test data
    prediction <- predict(model_final, newdata = pred_data, type = "prob")
    return(prediction)
}

#* Get information about API
#* @get /info
function() {
  # JSON friendly message with name and github pages site URL
  list(msg = "Zachary Rosen - https://zbrosen2.github.io/FinalProject/")
}

# Example endpoint usage (three function calls)
# http://localhost:8000/pred
# http://localhost:8000/pred?HighBP=0&HighChol=0&Smoker=0&PhysActivity=0&Age=9&BMI=30
# http://localhost:8000/pred?HighBP=1&HighChol=1&Smoker=1&PhysActivity=0&Age=10&BMI=45