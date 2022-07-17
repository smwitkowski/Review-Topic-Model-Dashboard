FROM rocker/r-ver:latest

RUN apt-get update -y && \
    apt-get install --no-install-recommends -y -q \
    libxml2 pandoc && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/ 

RUN install2.r --error --deps TRUE \
    stm 

RUN install2.r --error \
    shiny \
    paws \
    stringr \
    scales \
    plotly \
    dplyr \
    tidytext \
    reactable \
    tidyr \
    reshape2 \
    dotenv

COPY app .

EXPOSE 3838

CMD [ "R", "-e", "shiny::runApp(host = '0.0.0.0', port = 3838)" ]