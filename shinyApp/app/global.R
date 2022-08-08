library(paws)
library(stringr)

# TODO Consider removing. paws automatically finds these objects in the system env.
# library(dotenv)
# load_dot_env()


load_data_objects <- function(file_path) {
    if (endsWith(file_path, ".Rdata")) {

        # Load the R data saved in the S3 bucket.
        obj <- svc$get_object(
            Bucket = "topic-modeling-restaurant-reviews",
            Key = file_path
        )
        object_name <- load(rawConnection(obj$Body))
        object <- get(object_name)

        # Use regex to get the text after the last slash.
        restaurant_name <- str_extract(file_path, r'([^\/]+$)')
        restaurant_name <- gsub("_", " ", restaurant_name)
        restaurant_name <- gsub(".Rdata", "", restaurant_name)

        # Create a named list with the restaurant name and the data.
        return_list <- list()
        return_list[[restaurant_name]] <- object

        return(return_list)
    }
}


svc <- s3()

bucket_objects <- svc$list_objects_v2(
    Bucket = "topic-modeling-restaurant-reviews",
    Prefix = "topic-model-dashboard/data/final/topic-models"
)

file_paths <- unlist(lapply(bucket_objects$Contents, function(x) x$Key))
sample_files <- sample(file_paths, size = 100)

restaurant_data <- do.call(c, lapply(sample_files, load_data_objects))
restaurant_names <- names(restaurant_data)