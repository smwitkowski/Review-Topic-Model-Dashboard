library(shiny)
library(plotly)
library(reactable)

shinyUI(
    fluidPage(
        titlePanel("Topic Modeling NYC Restaurant Reviews"),
        fluidRow(
            column(
                6,
                h5("Instructions"),
                p("Write some stuff here")
            ),
            column(
                6,
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
            fluidRow(reactableOutput("representative_quotes"), style = "padding:2%;")
        )
    )
)
