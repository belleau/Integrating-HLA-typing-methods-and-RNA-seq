#' @title Compute the Hamming distance between two samples
#'
#' @description Computes the Hamming distance for two samples using both
#' alleles. See details section for more information about the Hamming
#' distance.
#'
#' @details The Hamming distance is given by
#' \eqn{min(s1A1 != s2A1 + s1A2 != s2A2, s1A1 != s2A2 + s1A2 != s2A1)} where
#' \code{s1} and \code{s2} are two samples and \code{A1} and \code{A2} are
#' there alleles.
#'
#' @param allele a \code{tibble} object with 3 mandatory columns:
#' "SampleName", "AlleleName" and "AlleleGroup".
#'
#' @return a \code{tibble} object with one row containing the minimum
#' Hamming distance and a \code{logical} column indicating whether
#' same allele was used. If the
#' distance is the same for both, then \code{NA} is returned.
#'
#' @examples
#'
#' ## Create a demo dataset
#' demoData <- data.frame(SampleName=c("s1", "s1", "s2", "s2"),
#'         AlleleName=c(1, 2, 1, 2), AlleleGroup=c(1, 3, 1, 5))
#'
#' ## Transform to tibble object
#' demoDataTibble <- dplyr::as_tibble(demoData)
#'
#' ## Calculate the Hamming distance on the demo dataset
#' HLAClustRView:::hamming_distance_digit1(demoDataTibble)
#'
#' @author Santiago Medina, Nissim Ranade
#'
#' @importFrom dplyr %>% mutate group_by summarise filter slice
#' @importFrom purrr reduce
#' @importFrom rlang .data
#' @importFrom tidyr crossing
#' @keywords internal
hamming_distance_digit1 <- function(allele) {

    stopifnot(nrow(allele) == 4)

    hdist <-
        allele %>%
        split(allele$SampleName) %>%
        reduce(.f = crossing) %>% # biparty graph to compute simularities
        mutate(
            is_similar = .data$AlleleGroup != .data$AlleleGroup1,
            same_allele = .data$AlleleName == .data$AlleleName1
            ) %>%
        group_by(.data$same_allele) %>%
        summarise(distance = sum(.data$is_similar)) %>%
        filter(.data$distance == min(.data$distance))

    result <- hdist

    ## check if the minimum distance is the same
    if (nrow(hdist) == 2) {
        result <- mutate(hdist, same_allele = NA) %>%
            slice(1)
    }

    return(result)
}

#' @title Sample Pair Distance
#'
#' @description Computes the Hamming Distance for a pair of samples and then
#' aggregates the
#' sum over the genes keeping information of which allele was used for
#' the distance
#'
#' @param sample_pair_data a \code{tibble} with columns GeneName (genes),
#' Allele (alleles), Digit1 (digit 1) and sample (see example data)
#'
#' @return  a \code{tibble} object with one row and column HammingDistance &
#' column data corresponding to the same_allele information
#'
#' @examples
#'
#' ## Load example dataset
#' data("example_sample_pair_data")
#'
#' ## Computes the Hamming distance for one pair of samples
#' HLAClustRView:::sample_pair_distance(example_sample_pair_data)
#'
#' @author Santiago Medina, Nissim Ranade
#'
#' @importFrom tidyr nest unnest spread
#' @importFrom dplyr group_by %>% summarise filter pull select mutate n
#' @importFrom utils data
#' @importFrom purrr map
#' @importFrom rlang .data
#' @keywords internal
sample_pair_distance <- function(sample_pair_data) {
    # make sure only two samples are given
    stopifnot(length(unique(sample_pair_data$SampleName)) == 2)

    # get complete cases, a gene should apear in both samples
    # to get the distance
    complete_genes <-
        sample_pair_data %>%
        group_by(.data$GeneName) %>%
        summarise(total = n()) %>%
        filter(.data$total == 4) %>%
        pull(.data$GeneName)

    distances_per_gene <-
        sample_pair_data %>%
        filter(.data$GeneName %in% complete_genes) %>% # keep complete cases
        group_by(.data$GeneName) %>%
        nest() %>%
        mutate(x = map(.data$data, hamming_distance_digit1)) %>%
        select(-data) %>%
        unnest(.data$x)

    distances_per_gene %>%
        mutate(HammingDistance = sum(.data$distance)) %>%
        select(-.data$distance) %>%
        group_by(.data$HammingDistance) %>%
        nest()
}


#' @title Calculate Hamming distance between all samples
#'
#' @description Takes an object containing HLA typing information for all
#' samples and computes the Hamming distance
#' for each pair of samples.
#'
#' @param hla_data a \code{list} of class \code{HLADataset} containing a
#' \code{tibble} object with the HLA typing information for all samples. At
#' least 2 samples must be present be able to calculate the metric.
#'
#' @return a \code{list} of class \code{HLAMetric}
#' containing the following elements:
#' \itemize{
#' \item \code{metric} a \code{character} string containing the name of the
#' metric "Hamming Distance".
#' \item \code{dist} a \code{matrix} that contains the Hamming distance between
#' samples.
#' }
#'
#' @details The Hamming distance is given by
#' \eqn{min(s1A1 != s2A1 + s1A2 != s2A2, s1A1 != s2A2 + s1A2 != s2A1)} where
#' \code{s1} and \code{s2} are two samples and \code{A1} and \code{A2} are
#' there alleles.
#'
#' @examples
#'
#' ## Load example dataset
#' data(demoHLADataset)
#'
#' ## Calculate Hamming distance metric
#' calculateHamming(demoHLADataset)
#'
#' @author Santiago Medina, Nissim Ranade
#'
#' @importFrom dplyr filter mutate select group_by inner_join as_tibble rename %>%
#' @importFrom tidyr unnest nest
#' @importFrom utils combn
#' @importFrom purrr map_lgl possibly map2
#' @importFrom rlang .data
#' @export
calculateHamming <- function(hla_data) {

    ## Validate that a HLADataset is passed as argument
    if (!"HLADataset" %in% class(hla_data)) {
        stop("hla_data must be of class \"HLADataset\"")
    }

    ## Validate that the HLA information is present and that
    ## at least 2 samples are present
    if(!is.null(hla_data$data)) {
        if (length(unique(hla_data$data$SampleName)) < 2) {
            stop("hla_data must contain information for at least 2 samples")
        }
    } else {
        stop("A entry called \"data\" is missing from hla_data")
    }

    hla_data <- hla_data$data

    hla_data <- select(hla_data, .data$SampleName, .data$GeneName,
                        .data$AlleleName, .data$AlleleGroup)

    ssample_pair_distance <- possibly(sample_pair_distance, otherwise = FALSE)

    map_data_to_distance <- function(s1, s2) {
        # get's the data for s1 and s2 and applys the distance function
        filter(hla_data, .data$SampleName %in% c(s1, s2)) %>%
            ssample_pair_distance()
        #print(paste0("s1 ", s1, " s2 ", s2))
    }

    sample_pairs <-
        unique(hla_data$SampleName) %>%
        combn(m = 2) %>%
        t() %>%
        as_tibble() %>%
        rename(SampleName1 = .data$V1, SampleName2 = .data$V2)

    distances <-
        sample_pairs %>%
        mutate(x = map2(.data$SampleName1, .data$SampleName2,
                            map_data_to_distance)) %>%
        mutate(is_error = map_lgl(.data$x, is.logical)) %>%
        filter(!.data$is_error) %>%
        select(-.data$is_error) %>%
        unnest(.data$x)

    distances %>%
        select(-.data$HammingDistance) %>%
        unnest(data) %>%
        group_by(.data$SampleName1, .data$SampleName2) %>%
        nest() %>%
        inner_join(
            y = select(distances, .data$SampleName1, .data$SampleName2,
                        .data$HammingDistance),
            by = c("SampleName1", "SampleName2")
            ) %>%
        rename(AlleleName_info = data)


    distanceMatrix <- makeDistanceMatrix(distances)


    ## Prepare HLADataset object
    res <- list()
    res[["dist"]] <- distanceMatrix
    res[["alleleInfo"]] <- distances
    res[["metric"]] <- "Hamming Distance"
    class(res) <- "HLAMetric"

    return(res)
}


#' @title Convert distance table to distance matrix
#'
#' @description This function takes a distance table under the form of a
#' \code{tibble} object and transforms it into a distance matrix
#' ready for clustering.
#'
#' @param outMet a \code{tibble} object containing distance metric for sample
#' pairs.
#'
#' @return a \code{matrix} containing the distance for sample pairs.
#'
#' @examples
#'
#' ## Tibble object containing a distance table
#' pairedData <- data.frame(SampleName1=c("ERR053", "ERR053", "ERR465"),
#'     SampleName2=c("ERR465", "ERR040", "ERR040"),
#'     HammingDistance = c(17, 18, 19))
#'
#' tibbleData <- dplyr::as_tibble(pairedData)
#'
#' ## Calculate distance matrix
#' HLAClustRView:::makeDistanceMatrix(tibbleData)
#'
#' @author Santiago Medina, Pascal Belleau, Astrid Deschenes
#' @keywords internal
makeDistanceMatrix <- function(outMet) {
    nbCase <- length(unique(outMet$SampleName1)) + 1

    matDia <- matrix(unlist(vapply(seq_len(nbCase), FUN.VALUE = double(nbCase),
                        FUN=function(x, outMetric, nbCase){
                            l <- NULL
                            if (x < nbCase) {
                                pos <- ((x-1) * (nbCase) - ((x-1)*x)/2 + 1)
                                l <- c(rep(0, x),
                                            outMetric$HammingDistance[
                                            pos:(pos+nbCase-x-1)])
                            } else {
                                l <- rep(0, x)
                            }

                            return(l)},
                        outMetric=outMet, nbCase=nbCase)), ncol=nbCase)

    # Add row names and column names to the distance matrix
    nameMat <- c(unique(unlist(outMet[,1])),
                unique(unlist(outMet[,2]))[length(unique(unlist(outMet[,2])))])

    rownames(matDia) <- nameMat
    colnames(matDia) <- nameMat

    return(matDia)
}


