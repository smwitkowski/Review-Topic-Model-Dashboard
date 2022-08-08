library(shiny)
library(scales)
library(stm)
library(plotly)
library(dplyr)
library(tidytext)
library(reactable)
library(tidyr)
library(reshape2)

shinyServer(function(input, output, session) {
    model_data <- reactive({
        # Load restaurant data
        restaurant_data[[input$restaurant_name]]
    })

    representative_quotes <- reactive({

        # Load in model information
        data <- model_data()

        model <- data$model
        meta <- data$meta
        k <- model$settings$dim$K

        # Create a "review" column with the content and title of the review
        meta$review <- apply(
            meta[, c("title_review", "review_full")], 1, paste,
            collapse = " - "
        )

        # Find the top N representative quotes
        quotes <- findThoughts(
            model, texts = meta$review,
            n = input$num_quotes
        )

        # Convert the quotes to a dataframe
        docs <- quotes$docs %>%
            as_tibble() %>%
            gather(key = "topic", value = "review")
        index <- quotes$index %>%
            as_tibble() %>%
            gather(key = "topic", value = "index")


        # Assign the index to a column and merge the metadata
        docs$doc_index <- index$index

        docs %>%
            merge(
                meta[, c("date", "score", "author_id")],
                by.x = "doc_index", by.y = "row.names"
            )
    })

    output$topic_num_dropdown <- renderUI({

        # Find the number of topics in the model
        k <- model_data()$model$settings$dim$K

        # Build a dropdown list of the topics to show quotes from
        selectInput(
            inputId = "topic_number",
            label = "Display Quotes from Topic Number",
            choices = paste("Topic ", seq.int(1, k), sep = ""),
            selected = "Topic 1",
            multiple = TRUE
        )
    })

    output$num_topic_slider <- renderUI({

        # Find the number of topics in the model
        k <- model_data()$model$settings$dim$K

        # Built a slider input for the number of topics to display
        sliderInput(
            inputId = "num_topics",
            label = "Number of Topics to Display:",
            min = 5,
            max = k,
            value = 5,
            step = 1
        )
    })

    output$topic_proportions <- renderPlotly({

        req(input$num_topics)

        # Load in model information
        model <- model_data()$model
        vocab <- model$vocab
        k <- model$settings$dim$K

        # Calculate the topic proportions for each document.
        # The columns are topic numbers and the rows are documents.
        # Taking the colMeans returns the average proportion across documents.
        topic_proportions <- colMeans(model$theta)


        # Find the top 5 FREX words
        frex_word_index <- calcfrex(model$beta$logbeta[[1]])
        frex_words <- apply(
            frex_word_index, 2,
            function(x) paste(vocab[x[1:5]], collapse = ", ")
        )

        # Arrange into a dataframe to facilitate plotting.

        topic_df <- data.frame(
            proportion = topic_proportions,
            topic_number = as.character(seq.int(1, length(topic_proportions))),
            words = frex_words
        )

        # Filter the dataframe to show the top N topics according to proportion.
        topic_df <- topic_df %>%
            mutate(proportion_rank = rank(desc(proportion), na.last = TRUE)) %>%
            top_n(n = input$num_topics, wt = proportion) %>%
            arrange(proportion) %>%
            as.data.frame(row.names = seq_len(nrow(.)))

        # Create a template for the hover information.
        hover_temp <- paste0(
            "<b>Topic Number</b>: ",
            topic_df$topic, "<br>",
            "<b>Proportion</b>: ",
            percent(topic_df$proportion, accuracy = .01), "<br>",
            "<b>Top 5 Words</b>: ",
            topic_df$words,
            "<extra></extra>"
        )

        # Plot the topic distributions
        plot_ly(
            data = topic_df,
            x = ~proportion,
            y = ~topic_number,
            type = "bar",
            orientation = "h",
            hovertemplate = hover_temp
        ) %>% layout(
            yaxis = list(
                title = "Topic Number",
                categoryorder = "array",
                categoryarray = as.character(~proportion_rank)
            ),
            xaxis = list(title = "Topic Proportion", tickformat = ".0%"),
            hoverlabel = list(bgcolor = "white", align = "left"),
            title = "Topic Distribution"
        )
    })

    output$review_correlation <- renderPlotly({

        req(input$num_topics)

        # Load in model information
        model_data <- model_data()
        
        # Calculate the correlation between the topics and the reviews.
        topic_proportions <- colMeans(model_data$model$theta)

        # Create a dataframe of topic proportions to facilitate filtering
        topic_df <- data.frame(
            proportion = topic_proportions,
            topic_number = as.character(seq.int(1, length(topic_proportions)))
        )

        # Filter the dataframe to show the top N topics according to proportion.
        topic_df <- topic_df %>%
            mutate(proportion_rank = rank(desc(proportion), na.last = TRUE)) %>%
            top_n(n = input$num_topics, wt = proportion) %>%
            arrange(proportion) %>%
            as.data.frame(row.names = seq_len(nrow(.)))

        # Load the effect estimate as a dataframe
        effect_estimate <- tidy(model_data$effect_estimate)
        effect_estimate$topic <- as.character(effect_estimate$topic)
        effect_estimate <- effect_estimate %>%
            filter(term == "score1" & topic %in% topic_df$topic) %>%
            mutate(bound = abs(estimate) + std.error * 2)

        # Find the x limit
        xlim <- max(effect_estimate$bound) * 1.25


        # Plot the effect estimates
        plot_ly(
            data = effect_estimate,
            x = ~estimate,
            y = ~topic,
            type = "scatter",
            mode = "markers",
            error_x = ~ list(
                array = std.error * 2,
                color = "#808080",
                size = 3
            )
        ) %>% layout(
            yaxis = list(
                title = "Score Estimate",
                categoryorder = "array",
                categoryarray = as.character(topic_df$topic_number)
            ),
            xaxis = list(
                title = "More Negative \t...\t More Postive",
                range = c(-xlim, xlim)
                ),
            hoverlabel = list(bgcolor = "white", align = "left"),
            title = "Score Distribution"
        )
    })

    output$representative_quotes <- renderReactable({

        req(input$topic_number)

        # Load in representative quotes
        quotes <- representative_quotes()

        #Filter to only show topics that are selected in the dropdown.
        quotes <- quotes %>%
            filter(topic %in% input$topic_number) %>%
            select(c(
                "doc_index",
                "author_id",
                "date",
                "topic",
                "score",
                "review"
            ))

        # Render reactable table
        reactable(
            quotes,
            columns = list(
                doc_index = colDef(name = "Document Index", width = 125),
                author_id = colDef(name = "Author ID", width = 125),
                date = colDef(name = "Review Date", width = 125),
                topic = colDef(name = "Topic", width = 125),
                score = colDef(name = "Score", width = 125),
                review = colDef(name = "Review", searchable = TRUE)
                ),
            highlight = TRUE,
            striped = TRUE,
            bordered = TRUE,
            searchable = TRUE,
            defaultPageSize = 5
        )
    })
})
