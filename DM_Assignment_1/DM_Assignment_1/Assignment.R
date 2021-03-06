if (!require("data.tree")) {
    install.packages("data.tree", dependencies = TRUE)
    library(data.tree)
}

# Description:  Grow a classification tree
# Returns: A classification tree
#  Arguments:
#  1. x: The data to split
#  2. y: labels that fit to x.
#  3. nmin - minimum amount of rows needed to split.
#  4. minleaf - minimum number of leafs a node should have
#  5. nfeat = Number of features to sample.
tree.grow <- function(x = c(), y = c(), nmin = 2, minleaf = 2, nfeat = (ncol(x))) {

  #first some checks
  if (is.null(x)) {
    stop("Feature table cannot be empty or null")
  }
  
  if (is.null(x)) {
    stop("Class label cannot be empty or null")
  }
  
  if (minleaf < 1) {
    stop("Must have at least 2 observations on a leaf node")
  }
  
  if (nmin <= 0) {
    stop("Minimum number of observations for a node has to be positive")
  }
  
  if (nfeat > ncol(x)) {
    stop("Cannot take a sample larger than the population.")
  }
  
  # Create the tree's root node.
  root <- node.create(node.label = "Root Node", node.type = "root", node.val = 0, x = x, y = y)
  # Recurse on root node.
  tree <- tree.grow.rec(root, nmin = nmin, minleaf = minleaf, nfeat)
  
  return(tree)
}

# Here x is a data matrix containing the attribute values of the cases for
# which predictions are required, and tr is a tree object created
# with the function tree.grow
tree.classify <- function(x = c(), tr) {
  
  y <- 0
  l <- 0
  
  for (index in 1:nrow(x)) {
    row = x[index,];
    result = tree.traverse(row, tr)
    l[[index]] <- result
  }
  
  return(l)
}

# Description:  Grow a classification tree
# Returns: A classification tree
#  Arguments:
#  1. x: The data to split
#  2. y: labels that fit to x.
#  3. nmin - minimum amount of rows needed to split.
#  4. minleaf - minimum number of leafs a node should have
#  5. nfeat = Number of features to sample.
#  5. m = number of trees to be used in the bagging
tree.grow.bag <- function(x = c(), y = c(), nmin = 2, minleaf = 2, nfeat = (ncol(x)) - 1, m) {
  
  result <- list()
  merged <- data.frame(x, y)
  
  for (i in 1:m) {
    xy <- merged[sample(nrow(merged),nrow(merged), replace = TRUE),]
    labels <- xy$y
    xy$y = NULL
    iTree = tree.grow(xy, labels, nmin, minleaf, nfeat)
    result[[i]] <- iTree
  }
  
  return(result)
}

# Description:  Classify using the provided trees and take the majority vote result of the trees
# Returns: A prediction for each sample
#  Arguments:
#  1. input = the input data
#  2. trees = the grown classification tree roots
tree.classify.bag <- function(input, trees) {
  c <- 0
  agg <- c()
  
  for (index in 1:nrow(input)) {
    row <- input[index,];
    r <- 0
    
    n <- 1
    
    for (tree in trees) {
      mat = matrix(row, ncol = length(row))
      class <- tree.classify(mat, tree)
      class_result <- class[[1]]
      r[[n]] = class_result
      n <- n + 1
    }
    
    result_class = tree.majorityVote(r)
    c[[index]] = result_class
  }
  
  return(c)
}

# Description: calcs impurity for a given node (1).
# data <- a dataframe for which to calculate the impurity
impurity <- function(data = c()) {
    l <- length(data)
    class_zero <- length(data[data == 0])
    class_uno <- length(data[data == 1])
    res <- (class_zero / l) * (class_uno / l)
    return(res)
}

# Description: calculates impurity reduction using the gini-index method. 
# orig <- the parent node
# uno <- the left child
# dos <- the right child
impurity_reduction <- function(orig = c(), uno = c(), dos = c()) {
    l <- length(orig)
    l_uno <- length(uno)
    l_dos <- length(dos)
    res <- impurity(orig) - ((l_uno / l) * impurity(uno) + (l_dos / l) * impurity(dos))
    return(res)
}

# Arg num_data: list of numeric data (a row of a column),
# Arg class_data: list of binary data (classification labels of num_data)
# returns: The best value of a split in num_data, numeric.
# description: Calculates all impurity reductions for all possible plits, then returns the value of the split with the greatest impurity reduction.
bestsplit <- function(num_data = c(), class_data = c()) {
    # sort numbers 
    num_sorted <- sort(unique(num_data))

    # find all split points => halfway
    splitpoints <- (num_sorted[1:(length(num_sorted) - 1)] + num_sorted[2:length(num_sorted)]) / 2
    orig <- impurity(class_data)
    best <- 0
    val <- (-1)

    #Check for all splits which one gives the highest impurity reduction.
    for (i in splitpoints) {
        res <- impurity_reduction(class_data, class_data[num_data > i], class_data[num_data <= i])
        if (res > val) {
            val <- res
            best <- i
        }
    }

    return(best)
}

# Description: Create a node
# Returns: a node.
#  Arguments:
#  1. label: name of node
#  2. type: right or left.
#  3. x: The data to split
#  4. y: labels that fit to x.
#  5. val: value of splitpoint in this node. 
node.create <- function(node.label = "", node.type = "left", type = "binary", node.val = "", x = c(), y = c()) {
    # Error checking
    if (type != "binary" && type != "numerical") {
        stop("Node can either be binary or numerical!")
    }

    if (node.type != "left" && node.type != "right" && node.type != "root") {
        stop("A node can either be left or right or root")
    }

    node <- Node$new()

    node$type <- node.type
    node$val <- node.val
    node$name <- node.label

    node$x <- x
    node$y <- y


    if (node.type == "left") {
        node$name <- paste(node.label, "<=", node.val, sep = '')
    } else if (node.type == "right") {
        node$name <- paste(node.label, ">", node.val, sep = '')
    }

    node$isTerminal <- FALSE

    return(node)
}

# Description: 
# Returns: The majority class of the predictions argument
# Arguments:
# 1. predictions = a set of 0,1 predictions
tree.majorityVote <- function(predictions) {

    zeros = 0
    ones = 0
    #print(predictions)

    for (i in predictions) {
        if (i == 1) {
            ones = ones + 1
        }
        else {
            zeros = zeros + 1
        }
    }

    if (zeros > ones) return(0)
    if (ones > zeros) return(1)

    #if they're equal, we must choose one randomly
    rand <- sample(1:100, 1)

    if (rand <= 50) return(1)
    else return(0)
}

# Description: 
# Returns: The majority class of the tree node labels
# Arguments:
# 1. node = a tree node for which to retrieve the majority class
tree.majority <- function(node) {
    height = nrow(node$x)
    classes = node$y

    agg = 0.0

    for (i in classes) {
        for (l in i) {

            final <- 0
            if (l >= 1) {
                final <- 1
            }
            agg = agg + final

        }
    }

    total = agg / height
    if (total <= 0.5) return(0)

    return(1)
}

# Description: 
# Returns: The class of the provided data point
# Arguments:
# 1. row <- the datapoint to predict
# 2. currentNode <- the current node to be reviewed(pass root of tree)
tree.traverse <- function(row, currentNode) {
    ch = length(currentNode$children)
    if (ch == 0) {
        return(tree.majority(currentNode))
    }

    split_column <- currentNode$split_col
    split_value <- currentNode$split_val

    val <- row[split_column]

    if (val <= split_value) {
        return(tree.traverse(row, currentNode$children[[1]]));
    }
    else {
        return(tree.traverse(row, currentNode$children[[2]]));
    }
}

# Description: 
# Returns: The class of the provided data point
# Arguments:
# 1. row <- the datapoint to predict
# 2. currentNode <- the current node to be reviewed(pass root of tree)
tree.grow.rec <- function(node = NULL, nmin = 2, minleaf = 2, nfeat) {

    node.data <- node$x
    node.sample<- node$x

    if (nfeat < (ncol(node.data))) {
       sample <- node.data[, sample.random.columns(node.data, nfeat)]
       node.sample <- sample
    }
     else {
        node.sample = node.data
     }

    node.classification <- node$y

    if (is.null(node.data)) {
        return(node)
    }
    if (nrow(node.data) < nmin) {

        return(node)
    }
    #if (impurity(node.data[, ncol(node.data)]) == 0) {
    if (impurity(node.classification) == 0) {
        return(node)
    }

    if (nrow(node.data) < minleaf) {
        return(node)
    }

    # FIND BEST col WITH BEST IMPUR REDUCTION FOR ALL POSSIBLE SPLITS
    split.col <- NULL
    split.value <- NULL
    reduction.max <- 0

    #skip first and last column ATLEAST FOR TEST DATA..
    #for (col in 1:(ncol(node.data) - 1)) {
    for (col in (1:ncol(node.sample))) {

        #only split when there is more then 1 unique data value, otherwise there is no posssible split.
        if (length(unique(node.sample[, col])) > 1) {

            #bestsplit means bestsplit for that col of data.
            #arg1 feature data
            #arg2 binary value if post bugs where found
            bs <- bestsplit(node.sample[, col], as.numeric(node.classification > 0))

            #get reduction on this split
            #arg1 all classification data
            #arg2 first half classification data
            #arg3 seconds half classification data
            reduction.total <- impurity_reduction(node.classification, node.classification[node.sample[, col] > bs], node.classification[node.sample[, col] <= bs])

            #check if this split is the best until now, if yes -> remember the split.
            if (reduction.total > reduction.max) {
                reduction.max <- reduction.total
                split.col <- col
                split.value <- bs
            }
        }
    }
    
    #check if found split if not return node.
    if (is.null(split.value)) {
        return(node)
    }
    
    #make right and left children
    leftChild <- node.create(node.label = 'n', node.type = "left", node.val = split.value,
                             x = node.data[node.sample[, split.col] <= split.value,], y = node.classification[node.sample[, split.col] <= split.value])
    rightChild <- node.create(node.label = 'n', node.type = "right", node.val = split.value,
                              x = node.data[node.sample[, split.col] > split.value,], y = node.classification[node.sample[, split.col] > split.value])
    
    #found column in samle data, find which column that is in the real data:
    split.col <- which( colnames(node.data)==colnames(node.sample[split.col]))
    node$split_col = split.col
    node$split_val = split.value

    #recurse
    tree.grow.rec(leftChild, nmin, minleaf, nfeat)
    tree.grow.rec(rightChild, nmin, minleaf, nfeat)

    #add children to parent
    node$AddChildNode(leftChild)
    node$AddChildNode(rightChild)

    return(node)
}

#Function to sample random coulms
#arg1 x, this is the data with all the columns.
#arg2 n, number of comns you want to sample.
sample.random.columns <- function(x, n) {
    if (n == ncol(x)) {
        return(sort(c(1:ncol(x)), decreasing = FALSE))
    }
    return(sort(c(sample(1:ncol(x), n, replace = F)), decreasing = FALSE))
}

#Removes the columns marked to be dropped
#arg1: csvFile 
#arg2: dropped, index of columns to be dropped
clean_csv <- function(csvFile, dropped) {
    for (i in dropped) {
        csvFile[, i] = NULL;
    }
    return(csvFile)
}

#returns condusion matrix, Precision & accurcy
#Observed is real labels
#Predicted is data precicted by tree
#example: getConfusionMatrix(data[,6], res)
measurements <- function(observed, predicted){
  #predicted <- factor(as.character(predicted), levels=unique(as.character(predicted)))
  #observed  <- as.factor(observed)
  
  cm <- as.matrix(table(observed, predicted))
  precision <- ((cm[2,2]) / (cm[2,2] + cm[1,2])) * 100
  accuracy <- (cm[1,1] +cm[2,2]) / (cm[1,1] + cm[1,2] + cm[2,1] + cm[2,2])
  recall<-((cm[2,2]) / (cm[2,2] + cm[2,1]))
  
  print('------')
  print('confusion matrix: ')
  print(cm)
  print('------')
  
  print('Precision: ')
  print(precision)
  print('Accuracy: ')
  print(accuracy)
  print('Recall: ')
  print(recall)
}

#run test on eclipse dataset
eclipse <- function() {
    #fake data input
    train_data <- read.csv('C://dm//eclipse-metrics-packages-2.0.csv', header = TRUE, sep = ";")
    test_data <- read.csv('C://dm//eclipse-metrics-packages-3.0.csv', header = TRUE, sep = ";")
    v <- 0

    v[[1]] = 1
    v[[2]] = 2

    train_data <- clean_csv(train_data, v)
    test_data <- clean_csv(test_data, v)

    train_labels <- train_data$post
    train_labels <- as.numeric(train_data$post > 0)

    train_data$post = NULL

    test_labels <- as.numeric(test_data$post > 0)
    test_data$post = NULL

    trees <- tree.grow.bag(train_data, train_labels, nmin = 15, minleaf = 5, nfeat = 41, m = 150)
    predictions <- tree.classify.bag(test_data, trees)
    
    measurements(test_labels, predictions)
}

#run test on indian dataset
indians <- function() {
    train_data <- read.csv('C://data.csv')

    train_labels = train_data[, 9]
    train_data[, 9] = NULL

    tree <- tree.grow(train_data, train_labels)
    pr <- tree.classify(train_data, tree)

    print(pr)
    tree <- tree.grow(x = train_data, y =train_labels, minleaf = 2, nmin = 2, nfeat = 5)
    pr <- tree.classify(train_data, tree)
    measurements(train_labels, pr)
}

eclipse()