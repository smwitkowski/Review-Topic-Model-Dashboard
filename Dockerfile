FROM rocker/r-ver:4.1.0

RUN apt-get update -y && \
  apt-get install --no-install-recommends -y -q \
  libxml2 pandoc && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/ 

RUN install2.r --error --deps TRUE \
  stm \
  aws.s3

RUN install2.r --error \
  xml2 \
  httr \
  jsonlite \
  lubridate \
  logger \
  base64enc \
  dplyr \
  tm \
  zoo \ 
  plyr \
  textcat \
  optparse \
  tidytext

COPY src/functions.R .

ENTRYPOINT ["Rscript", "functions.R"]