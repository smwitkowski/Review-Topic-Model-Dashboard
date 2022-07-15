library(httr)
library(aws.s3)
library(logger)
library(dplyr)
library(stm)
library(tm)
library(zoo)
library(textcat)
library(tidytext)
library(optparse)

read_file <- function(file_name, bucket_name) {
  obj <- aws.s3::s3read_using(
    object = file_name,
    bucket = bucket_name,
    FUN = read.csv
  )
  return(obj)
}

prepare_covariates <- function(reviews) {
  reviews$score <- plyr::mapvalues(
    reviews$sample,
    from = c("Positive", "Negative"),
    to = c(1, 0)
  )

  reviews$year_month <- as.integer(as.factor(
    zoo::as.yearmon((lubridate::as_date(reviews$date)))
  ))

  return(reviews)
}

exclude_non_english <- function(reviews) {
  reviews$language <- unlist(lapply(reviews$concat_review, textcat::textcat))
  reviews <- reviews[reviews$language == "english", ]
  return(reviews)
}

clean_text <- function(text) {
  text <- tolower(text)
  text <- tm::removePunctuation(text)
  text <- tm::removeNumbers(text)
  text <- tm::removeWords(text, words = tm::stopwords())
  text <- tm::stemDocument(text)
  return(text)
}

prepare_documents <- function(reviews) {
  logger::log_info("Running textProcessor")
  logger::log_info("Data size: ", nrow(reviews))

  processed <- stm::textProcessor(
    reviews$concat_review,
    metadata = reviews,
    lowercase = FALSE,
    removestopwords = FALSE,
    removenumbers = FALSE,
    removepunctuation = FALSE,
    ucp = FALSE,
    stem = FALSE,
    wordLengths = c(3, Inf),
    sparselevel = 1,
    language = "en",
    verbose = TRUE,
    onlycharacter = FALSE,
    striphtml = FALSE,
    customstopwords = NULL,
    custompunctuation = NULL,
    v1 = FALSE
  )

  logger::log_info("Running prepDocuments")
  out <- stm::prepDocuments(
    processed$documents,
    processed$vocab,
    processed$meta
  )

  return(out)
}

build_model <- function(docs, vocab, meta) {
  model <- stm::stm(
    documents = docs,
    vocab = vocab,
    K = 0,
    prevalence = ~ score,
    content = ~ score,
    max.em.its = 10000,
    emtol = 1e-07,
    data = meta,
    init.type = "Spectral",
    verbose = FALSE
  )

  return(model)
}

sample_data <- function(reviews, nrestaurants) {
  unique_restaurants <- unique(reviews$restaurant_name)
  sampled_restaurants <- sample(unique_restaurants, size = nrestaurants)
  reviews <- reviews[reviews$restaurant_name %in% sampled_restaurants, ]

  return(reviews)
}

get_args <- function() {
  parser <- optparse::OptionParser()
  parser <- optparse::add_option(
    parser, c("-p", "--path"),
    type = "character",
    help = "The full path to the .csv file containing reveiws"
  )

  parser <- optparse::add_option(
    parser, c("-b", "--bucket"),
    type = "character", help = "The bucket name containing the review files"
  )

  parser <- optparse::add_option(
    parser, c("-r", "--restaurant"),
    type = "character",
    help = "The restaurant to model.", default = NULL
  )
  parser <- optparse::add_option(
    parser, c("--id"),
    type = "character",
    help = "The restaurant to model.", default = NULL
  )
  parser <- optparse::add_option(
    parser, c("--key"),
    type = "character",
    help = "The full path to the .csv file containing reveiws"
  )

  parser <- optparse::add_option(
    parser, c("--region"),
    type = "character", help = "The bucket name containing the review files"
  )


  args <- optparse::parse_args(parser)

  return(args)
}

main <- function(file_name,
                 bucket_name,
                 restaurant_name) {
  logger::log_info("Reading in file ", file_name, " from bucket ", bucket_name)
  reviews <- read_file(file_name, bucket_name)


  if (is.character(restaurant_name)) {
    reviews <- reviews[reviews$restaurant_name == restaurant_name, ]
    if (nrow(reviews) < 100) {
      stop(paste0("Fewer than 100 reviews for ", restaurant_name))
    }
  }

  logger::log_info("Preparing data")
  reviews$concat_review <- paste(reviews$title_review, reviews$review_full)
  reviews$concat_review <- unlist(lapply(reviews$concat_review, clean_text))
  reviews <- prepare_covariates(reviews)
  reviews <- exclude_non_english(reviews)

  logger::log_info("Preparing documents")
  out <- prepare_documents(reviews)
  docs <- out$documents
  vocab <- out$vocab
  meta <- out$meta

  logger::log_info("Building model")
  model <- build_model(docs, vocab, meta)
  k <- model$settings$dim$K

  effect_estimate <- estimateEffect(
    as.formula(
      paste("1:",
        substitute(k),
        "~ score",
        collapse = ""
      )
    ),
    stmobj = model,
    metadata = meta
  )

  logger::log_info("Saving R data")
  save_obj <- list(
    model = model,
    docs = docs,
    vocab = vocab,
    meta = meta,
    effect_estimate = effect_estimate
  )

  if (is.character(restaurant_name)) {
    rdata_name <- gsub(" ", "_", restaurant_name)
  } else {
    rdata_name <- unlist(strsplit(file_name, "/"))
    rdata_name <- rdata_name[length(rdata_name)]
    rdata_name <- gsub(".csv", "", rdata_name)
    rdata_name <- gsub("_", " ", rdata_name)
  }

  aws.s3::s3save(
    save_obj,
    object = paste0("topic-model-dashboard/data/final/topic-models/", rdata_name, ".Rdata"),
    bucket = bucket_name
  )
}

args <- get_args()

Sys.setenv(
  "AWS_ACCESS_KEY_ID" = args$id,
  "AWS_SECRET_ACCESS_KEY" = args$key,
  "AWS_DEFAULT_REGION" = args$region
)

logger::log_info("File path passed in is ", args$path)
logger::log_info("Bucket name passed in is ", args$bucket)

if (is.character(args$restaurant)) {
  logger::log_info("Restaurant passed in is ", args$restaurant)
} else {
  logger::log_info("No restaurant given, building model on whole file")
}

main(
  args$path,
  args$bucket,
  args$restaurant
)
