### Unit tests for functions in draw_cluster.R file

library(HLAClustRView)


data("demoHLADataset")

### Tests draw_dendogram() function

context("Test for draw_dendogram() function")

test_that("draw_dendogram() must return error hlaMetric argument is string", {
    message <- "hlaMetric must be of class \"HLAMetric\""
    expect_error(draw_dendogram(hlaMetric = "BigFoot"), message)
})


### Tests draw_heatmap() function

context("Test for draw_heatmap() function")

test_that("draw_heatmap() must return error hlaMetric argument is string", {
    message <- "hlaMetric must be of class \"HLAMetric\""
    expect_error(draw_heatmap(hlaMetric = "Bonhomme Carnaval"), message)
})

test_that("draw_heatmap() must return an Heatmap class object", {

    hammingMetric <- calculateHamming(demoHLADataset)

    graphResult <- draw_heatmap(hammingMetric)

    expect_that(graphResult, is_a("Heatmap"))
})
