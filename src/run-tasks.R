library(paws)
library(dplyr)
library(dotenv)
library(optparse)
library(aws.s3)
library(logger)

read_file <- function(file_name, bucket_name) {
    obj <- aws.s3::s3read_using(
        object = file_name,
        bucket = bucket_name,
        FUN = read.csv
    )
    return(obj)
}

get_clusters <- function(svc) {
    existing_clusters <- svc$list_clusters()

    cluster_arns <- as.vector(existing_clusters$clusterArns)

    cluster_names <- lapply(cluster_arns, function(x) {
        arn_split <- unlist(strsplit(x, "/"))
        cluster_name <- arn_split[length(arn_split)]
        return(cluster_name)
    })
    return(unlist(cluster_names))
}

get_args <- function() {
    parser <- optparse::OptionParser()

    parser <- add_option(
        parser, c("-c", "--cluster"),
        type = "character",
        help = "The name of the cluster to use when creating tasks"
    )
    parser <- add_option(
        parser, c("-e", "--env"),
        default = ".env",
        type = "character",
        help = "The name of you environment file containing AWS credentials"
    )
    parser <- add_option(
        parser, c("-p", "--path"),
        type = "character",
        help = "The full path to the .csv file containing reveiws"
    )
    parser <- add_option(
        parser, c("-b", "--bucket"),
        type = "character",
        help = "The bucket name containing the review files"
    )
    parser <- add_option(
        parser, c("-t", "--task"),
        type = "character",
        help = "The bucket name containing the review files"
    )

    args <- optparse::parse_args(parser)

    return(args)
}

args <- get_args()

dotenv::load_dot_env(file = args$env)
logger::log_info("Reading in file ", args$path, " from bucket ", args$bucket)

reviews <- read_file(args$path, args$bucket)

unique_restaurants <- reviews %>%
    group_by(restaurant_name) %>%
    filter(n() >= 100) %>%
    distinct(restaurant_name) %>%
    pull(restaurant_name)


# Authenticate AWS

logger::log_info("Checking that cluster ", args$cluster, " exists.")
svc <- ecs()

existing_clusters <- get_clusters(svc)

if (!args$cluster %in% existing_clusters) {
    svc$create_cluster(clusterName = args$cluster)
}


for (restaurant in unique_restaurants) {
    logger::log_info("Running task for ", restaurant)
    task <- svc$run_task(
        cluster = args$cluster,
        count = 1,
        launchType = "FARGATE",
        networkConfiguration = list(
            awsvpcConfiguration = list(
                subnets = list(
                    "subnet-089ec97b46ddf7242"
                ),
                securityGroups = list(
                    "sg-0fc07c7ff27f19268"
                ),
                assignPublicIp = "ENABLED"
            )
        ),
        overrides = list(
            containerOverrides = list(
                list(
                    name = "build-topic-model",
                    command = list(
                        "--path",
                        args$path,
                        "--bucket",
                        args$bucket,
                        "--restaurant",
                        restaurant,
                        "--key",
                        Sys.getenv("AWS_SECRET_ACCESS_KEY"),
                        "--id",
                        Sys.getenv("AWS_ACCESS_KEY_ID"),
                        "--region",
                        Sys.getenv("AWS_DEFAULT_REGION")
                    )
                )
            )
        ),
        taskDefinition = args$task
    )

    task_arn_split <- unlist(strsplit(task$tasks[[1]]$taskArn, "/"))
    task_arn <- task_arn_split[length(task_arn_split)]

    task_complete <- FALSE
    i <- 1
    last_task_status <- "None"
    while (!task_complete) {
        task_status <- svc$describe_tasks(
            cluster = args$cluster,
            tasks = list(task_arn)
        )$tasks[[1]]$lastStatus

        if (task_status == "RUNNING") {
            logger::log_info(
                "Task is now running, moving to next restaurant."
            )
            task_complete <- TRUE
        } else if (task_status == "STOPPED") {
            logger::log_info(
                "Task has stopped, check logs for details.",
                "Moving on to next restaurant."
            )
            task_complete <- TRUE
        } else {
            if (task_status != last_task_status) {
                logger::log_info("Task has status: ", task_status)
                last_task_status <- task_status
            }
            Sys.sleep(min(i, 30))
            i <- i + 1
        }
    }
}
