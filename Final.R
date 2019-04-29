# installing libraries
#install.packages('e1071')
#install.packages('rpart.plot')
#install.packages('caret')
#install.packages('pROC')
#install.packages('Hmisc')
#install.packages('ggplot2')
#install.packages('precrec')
library('precrec')
library('Hmisc')
library('caret')
library('e1071')
library('rpart')
library('rpart.plot')
library('pROC')
library('ggplot2')
library(data.table)

# reading csv file
bank = read.csv("bank-full.csv", sep = ";")
# renaming dataset columns
colnames(bank)[5] <- "default_credit"
colnames(bank)[7] <- "housing_loan"
colnames(bank)[8] <- "personal_loan"
colnames(bank)[9] <- "contact_type"
colnames(bank)[13] <- "current_campaign_contact_count"
colnames(bank)[14] <- "days_passed"
colnames(bank)[15] <- "previous_campaign_contact_count"
colnames(bank)[16] <- "previous_campaign_outcome"
#droping balance column as it is an undocumented column
bank$balance <- NULL

## Data Exploration

#data has approx 45000 data points with 17 features.
dim(bank)

# datatypes of columns
sapply(bank, class)

#summary of columns
summary(bank)

#categorical features unique values
categorical_variables = names(bank)[sapply(bank, class) == "factor"]
categorical_column_values = sapply(bank[categorical_variables], function(x) unique(x))
categorical_column_values

#checking for nullvalues in the bank dataset
na_count <- sapply(bank, function(x) sum(which(is.na(x))))
na_count <- data.frame(na_count)
na_count

# Density plot Before Preprocessing
ggplot(bank, aes(x=age))+ geom_density(color="darkblue", fill="lightblue")
ggplot(bank, aes(x=duration))+ geom_density(color="darkblue", fill="lightgreen")


##Data Preprocessing

#removing missing (unknown) values wrt jobs

#We will handle missing values (unknown) of education with respect to job
bank_final = bank[!(bank$education == "unknown" & bank$job == "unknown"),]

getmode <- function(v) {
  uniqv <- unique(v)
  uniqv[which.max(tabulate(match(v, uniqv)))]
}

temp = data.frame(bank_final$job, bank_final$education)
names(temp)[1] <- "job"
names(temp)[2] <- "education"
uni = unique(temp["job"],) 
jobS = temp[temp["job"] == "technician",]
getmode(jobS$education)

# to replace values, we have to change the ‘factor’ class of column to character and later change back
bankData = subset(bank_final, job != 'unknown' | education != 'unknown')
dim(bankData)
for (category in levels(bankData$job)){
  # Creates a DF which only consists of education data for Specific ‘category’
  bankD = data.frame(table(unlist(bankData[bankData$job == category,]$education)))
  
  # According to the above table, finding the mod
  mod = bankD[1][bankD$Freq == max(bankD$Freq),]
  
  bankData$education = as.character(bankData$education)
  bankData$education[bankData$job == category & bankData$education == 'unknown'] = as.character(mod)
  bankData$education = as.factor(bankData$education)
}

# before replacing unknown columns
table(unlist(bankData$job))

## replacing all unknown job values with mode of job column which i blue-collar
data = data.frame(table(unlist(bankData$job)))
mod = data$Var1[data$Freq == max(data$Freq)]
bankData$job = as.character(bankData$job)
bankData$job[bankData$job == 'unknown'] = as.character(mod)
bankData$job = as.factor(bankData$job)

# after replacing unknown columns
table(unlist(bankData$job))

# label encoding features
bankData$job <- as.numeric(factor(bankData$job)) -1
bankData$education <- as.numeric(factor(bankData$education)) -1
bankData$marital <- as.numeric(factor(bankData$marital)) -1
bankData$default_credit <- as.numeric(factor(bankData$default_credit)) -1
bankData$housing_loan <- as.numeric(factor(bankData$housing_loan)) -1
bankData$personal_loan <- as.numeric(factor(bankData$personal_loan)) -1
bankData$contact_type <- as.numeric(factor(bankData$contact_type)) -1
bankData$month <- as.numeric(factor(bankData$month)) -1
bankData$previous_campaign_outcome <- as.numeric(factor(bankData$previous_campaign_outcome)) -1
bankData$y <- as.numeric(factor(bankData$y)) -1


## After preprocessing, data exploration
for (col in colnames(bankData)){
  print(col)
  #res <- cor.test(bankData$y, bankData[,col], method = "pearson")
  print(cor(bankData[,col], bankData$y))
}

## Removing outliers

# there are only upper outliers and no bottom outliers on both age and duration features
# before capping
quantile(bankData$age)
quantile(bankData$duration)
boxplot(bankData$age)
boxplot(bankData$duration)

for (colName in c('age', 'duration')) {
  high = quantile(bankData[,colName])[4] + 1.5*IQR(bankData[,colName])
  low = quantile(bankData[,colName])[2] - 1.5*IQR(bankData[,colName])
  for (index in c(1:nrow(bankData))) {
    bankData[,colName][index] = ifelse(bankData[,colName][index] > high, high, bankData[,colName][index])
    bankData[,colName][index] = ifelse(bankData[,colName][index] < low, low, bankData[,colName][index])
  }
}

# after capping
quantile(bankData$age)
quantile(bankData$duration)
boxplot(bankData$age)
boxplot(bankData$duration)

# Density plot after Preprocessing
ggplot(bankData, aes(x=age))+ geom_density(color="darkblue", fill="lightblue")
ggplot(bankData, aes(x=duration))+ geom_density(color="darkblue", fill="lightgreen")

bankData$duration <- NULL


## Test and train splitting
bound <- floor((nrow(bankData)/4)*3)         #define % of training and test set
bankData <- bankData[sample(nrow(bankData)), ]           #sample rows 
trainData <- bankData[1:bound, ]              #get training set
testData <- bankData[(bound+1):nrow(bankData), ]
trainDataExceptLast = trainData[c(1:14)]
testDataExceptLast = testData[c(1:14)]

## Standardizing columns
train_scaled <- preProcess(trainDataExceptLast, method = c("center", "scale"))
train <- predict(train_scaled, trainDataExceptLast)
test <- predict(train_scaled, testDataExceptLast)
summary(train)


## Modeling

#Decision Tree
fit <- rpart(trainData$y~., data = train, method="class")
predicted = predict(fit, test, type='class')
table_mat <- table(testData$y, predicted)
accuracy_Test <- sum(diag(table_mat)) / sum(table_mat)
accuracy_Test

rpart.plot(fit, box.palette="RdBu", shadow.col="gray", nn=TRUE)

confusionMatrix(table_mat)

precrec_obj <- evalmod(scores = testData$y, labels = predicted)
autoplot(precrec_obj)



#Naive Bayes
library(mltools)
train_h <- one_hot(as.data.table(trainData))
dim({train_h})
str(train_h)

test_h <- one_hot(as.data.table(testData))
dim({test_h})
str(test_h)

trainData$y <- as.factor(trainData$y)
testData$y <- as.factor(testData$y)
bankData$y <- as.factor(bankData$y)

model <- naiveBayes(trainData[, !names(trainData) %in% c("y")],
                    trainData$y, na.action = na.pass)

x<- testData[, !names(testData) %in% c("y")]
y <- testData$y
predicted_y <- predict(model, x)

bayes.table <- table(predict(model, x), y)
bayes.table
confusionMatrix(bayes.table)

predicted_y = as.double(as.character(predicted_y))

#ROC Curve for Naive bayes
precrec_obj <- evalmod(scores = predicted_y, labels = y)
autoplot(precrec_obj)

#knn model
bankData$y <- as.numeric(factor(bankData$y)) -1
dim(bankData)
normalize <- function(x) {
  return ((x - min(x)) / (max(x) - min(x))) }

bankData_n <- as.data.frame(lapply(bankData[1:ncol(bankData)], normalize))

sapply(bankData, class)

dim(bankData_n)

library(class)

# Splitting the data
knn_train <- bankData_n[1:bound,]
knn_test <- bankData_n[(bound+1):nrow(bankData_n),]
dim(knn_train)
dim(knn_test)

train_labels <- knn_train[,ncol(bankData_n)]
test_labels <- knn_test[,ncol(bankData_n)]
length(train_labels)
length(test_labels)

# Building the model and predicting on test data
test_pred <- knn(knn_train[,1:(ncol(bankData_n)-1)], knn_test[,1:(ncol(bankData_n)-1)], train_labels, k=10)

# comparing the predicted values and the actual test label values
table_mat <- table(test_labels, test_pred)
table_mat

# Measuring the accuracy
accuracy_Test <- sum(diag(table_mat)) / sum(table_mat)
accuracy_Test

confusionMatrix(table_mat)

#ROC Curve for KNN
precrec_obj <- evalmod(scores = test_labels, labels = test_pred)
autoplot(precrec_obj)

