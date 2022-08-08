library(shiny)
library(plotly)
library(reactable)


shinyUI(
    fluidPage(
        titlePanel("Topic Modeling NYC Restaurant Reviews"),
        fluidRow(
            column(
                6,
                p('This dashboard contains topic models for New York City restaurants.'),
                p('First, select a restaurant from the drop down found under "Restaurant Name". Two charts will be made available. The first titled "Topic Distribution" shows the percetage of documents that fall in each topic. By default, it only displays the top five topics. You can change the number of topics shown in that plot by adjusting the "Number of Topics to Display" slider.'),
                p('The second chart titled "Score Distribution" shows how positive or negative the topics are according to the scores the reviews gave. This chart also changes with the previously mentioned slider.'),
                p('For more information on this dashboard, visit the project\'s To dig deeping into a particular topic, there is a table at the bottom of the dashboard that shown the most "repesentative" reviews for a given topic. These reviews are shwon in order of how well they capture the essence of a topic. You can include or exclude particular topics by using the "Display Quotes from Topic Number" selector. Additionaly, you can increase or decrease the number of reviews shown by adjusting the "number of Reviews to Display per Topic" slider.')
            ),
            column(
                3,
                selectInput(
                    "restaurant_name",
                    "Restaurant Name",
                    restaurant_names
                ),
                uiOutput("num_topic_slider")
            ),
            column(
                3,
                uiOutput("topic_num_dropdown"),
                sliderInput(
                    "num_quotes",
                    "Number of Reviews to Display per Topic:",
                    min = 3,
                    max = 20,
                    value = 5,
                    step = 1
                )
            )
        ),
        fluidRow(
            column(6, plotlyOutput("topic_proportions"), style = "padding:2%;"),
            column(6, plotlyOutput("review_correlation"), style = "padding:2%;")
        ),
        br(),
        fluidRow(
            reactableOutput("representative_quotes"),
            style = "padding:2%;"
        )
    )
)
