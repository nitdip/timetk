#' Visualize Anomalies for One or More Time Series
#'
#' An interactive and scalable function for visualizing anomalies in time series data.
#' Plots are available in interactive `plotly` (default) and static `ggplot2` format.
#'
#' @inheritParams tk_anomaly_diagnostics
#' @param .data A `tibble` or `data.frame` with a time-based column
#' @param .date_var A column containing either date or date-time values
#' @param .value A column containing numeric values
#' @param .facet_vars One or more grouping columns that broken out into `ggplot2` facets.
#'  These can be selected using `tidyselect()` helpers (e.g `contains()`).
#' @param .facet_ncol Number of facet columns.
#' @param .facet_scales Control facet x & y-axis ranges. Options include "fixed", "free", "free_y", "free_x"
#' @param .line_color Line color.
#' @param .line_size Line size.
#' @param .line_type Line type.
#' @param .line_alpha Line alpha (opacity). Range: (0, 1).
#' @param .anom_color Color for the anomaly dots
#' @param .anom_alpha Opacity for the anomaly dots. Range: (0, 1).
#' @param .anom_size Size for the anomaly dots
#' @param .ribbon_fill Fill color for the acceptable range
#' @param .ribbon_alpha Fill opacity for the acceptable range. Range: (0, 1).
#' @param .legend_show Toggles on/off the Legend
#' @param .title Plot title.
#' @param .x_lab Plot x-axis label
#' @param .y_lab Plot y-axis label
#' @param .color_lab Plot label for the color legend
#' @param .interactive If TRUE, returns a `plotly` interactive plot.
#'  If FALSE, returns a static `ggplot2` plot.
#'
#'
#' @return A `plotly` or `ggplot2` visualization
#'
#' @details
#'
#' The `plot_anomaly_diagnostics()` is a visualtion wrapper for `tk_anomaly_diagnostics()`
#' group-wise anomaly detection, implements a 2-step process to
#' detect outliers in time series.
#'
#' __Step 1: Detrend & Remove Seasonality using STL Decomposition__
#'
#' The decomposition separates the "season" and "trend" components from the "observed" values
#' leaving the "remainder" for anomaly detection.
#'
#' The user can control two parameters: frequency and trend.
#'
#' 1. `.frequency`: Adjusts the "season" component that is removed from the "observed" values.
#' 2. `.trend`: Adjusts the trend window (t.window parameter from [stats::stl()] that is used.
#'
#' The user may supply both `.frequency` and `.trend` as time-based durations (e.g. "6 weeks") or
#' numeric values (e.g. 180) or "auto", which predetermines the frequency and/or trend based on
#' the scale of the time series using the [tk_time_scale_template()].
#'
#' __Step 2: Anomaly Detection__
#'
#' Once "trend" and "season" (seasonality) is removed, anomaly detection is performed on the "remainder".
#' Anomalies are identified, and boundaries (recomposed_l1 and recomposed_l2) are determined.
#'
#' The Anomaly Detection Method uses an inner quartile range (IQR) of +/-25 the median.
#'
#' _IQR Adjustment, alpha parameter_
#'
#' With the default `alpha = 0.05`, the limits are established by expanding
#' the 25/75 baseline by an IQR Factor of 3 (3X).
#' The _IQR Factor = 0.15 / alpha_ (hence 3X with alpha = 0.05):
#'
#' - To increase the IQR Factor controlling the limits, decrease the alpha,
#' which makes it more difficult to be an outlier.
#' - Increase alpha to make it easier to be an outlier.
#'
#'
#' - The IQR outlier detection method is used in `forecast::tsoutliers()`.
#' - A similar outlier detection method is used by Twitter's `AnomalyDetection` package.
#' - Both Twitter and Forecast tsoutliers methods have been implemented in Business Science's `anomalize`
#'  package.
#'
#' @seealso
#' - [tk_anomaly_diagnostics()]: Group-wise anomaly detection
#'
#'
#' @references
#' 1. CLEVELAND, R. B., CLEVELAND, W. S., MCRAE, J. E., AND TERPENNING, I.
#'  STL: A Seasonal-Trend Decomposition Procedure Based on Loess.
#'  Journal of Official Statistics, Vol. 6, No. 1 (1990), pp. 3-73.
#'
#' 2. Owen S. Vallis, Jordan Hochenbaum and Arun Kejariwal (2014).
#'  A Novel Technique for Long-Term Anomaly Detection in the Cloud. Twitter Inc.
#'
#'
#'
#' @examples
#' library(tidyverse)
#' library(timetk)
#'
#' walmart_sales_weekly %>%
#'     group_by(id) %>%
#'     plot_anomaly_diagnostics(Date, Weekly_Sales,
#'                              .message = FALSE,
#'                              .facet_ncol = 3,
#'                              .ribbon_alpha = 0.25,
#'                              .interactive = FALSE)
#'
#'
#'
#' @name plot_anomaly_diagnostics
#' @export
plot_anomaly_diagnostics <- function(.data, .date_var, .value, .facet_vars = NULL,

                                     .frequency = "auto", .trend = "auto",
                                     .alpha = 0.05, .max_anomalies = 0.2,
                                     .message = TRUE,

                                     .facet_ncol = 1, .facet_scales = "free",

                                     .line_color = "#2c3e50", .line_size = 0.5,
                                     .line_type = 1, .line_alpha = 1,

                                     .anom_color = "#e31a1c",
                                     .anom_alpha = 1, .anom_size = 1.5,

                                     .ribbon_fill = "grey20", .ribbon_alpha = 0.20,

                                     .legend_show = TRUE,

                                     .title = "Anomaly Diagnostics",
                                     .x_lab = "", .y_lab = "",
                                     .color_lab = "Anomaly",

                                     .interactive = TRUE) {

    # Checks
    value_expr <- rlang::enquo(.value)
    date_var_expr <- rlang::enquo(.date_var)

    if (!is.data.frame(.data)) {
        rlang::abort(".data is not a data-frame or tibble. Please supply a data.frame or tibble.")
    }
    if (rlang::quo_is_missing(date_var_expr)) {
        rlang::abort(".date_var is missing. Please supply a date or date-time column.")
    }
    if (rlang::quo_is_missing(value_expr)) {
        rlang::abort(".value is missing. Please supply a numeric column.")
    }


    UseMethod("plot_anomaly_diagnostics", .data)
}

#' @export
plot_anomaly_diagnostics.data.frame <- function(.data, .date_var, .value, .facet_vars = NULL,

                                                .frequency = "auto", .trend = "auto",
                                                .alpha = 0.05, .max_anomalies = 0.2,
                                                .message = TRUE,

                                                .facet_ncol = 1, .facet_scales = "free",

                                                .line_color = "#2c3e50", .line_size = 0.5,
                                                .line_type = 1, .line_alpha = 1,

                                                .anom_color = "#e31a1c",
                                                .anom_alpha = 1, .anom_size = 1.5,

                                                .ribbon_fill = "grey20", .ribbon_alpha = 0.20,

                                                .legend_show = TRUE,

                                                .title = "Anomaly Diagnostics",
                                                .x_lab = "", .y_lab = "",
                                                .color_lab = "Anomaly",

                                                .interactive = TRUE) {

    # Tidy Eval Setup
    value_expr    <- rlang::enquo(.value)
    date_var_expr <- rlang::enquo(.date_var)
    facets_expr   <- rlang::enquo(.facet_vars)

    # Facet Names
    facets_expr <- rlang::syms(names(tidyselect::eval_select(facets_expr, .data)))

    data_formatted      <- tibble::as_tibble(.data)
    .facet_collapse     <- TRUE
    .facet_collapse_sep <- " "

    # FACET SETUP ----
    facet_names <- data_formatted %>% dplyr::select(!!! facets_expr) %>% colnames()

    if (length(facet_names) > 0) {
        # Handle facets
        data_formatted <- data_formatted %>%
            dplyr::ungroup() %>%
            dplyr::mutate(.facets_collapsed = stringr::str_c(!!! rlang::syms(facet_names),
                                                             sep = .facet_collapse_sep)) %>%
            dplyr::mutate(.facets_collapsed = forcats::as_factor(.facets_collapsed)) %>%
            dplyr::select(-(!!! rlang::syms(facet_names))) %>%
            dplyr::group_by(.facets_collapsed)

        facet_names <- ".facets_collapsed"
    }

    # data_formatted

    # ---- DATA PREPARATION ----

    # Seasonal Diagnostics
    data_formatted <- data_formatted %>%
        tk_anomaly_diagnostics(
            .date_var      = !! date_var_expr,
            .value         = !! value_expr,
            .frequency     = .frequency,
            .trend         = .trend,
            .alpha         = .alpha,
            .max_anomalies = .max_anomalies,
            .message       = .message
        )

    data_formatted

    # ---- VISUALIZATION ----

    g <- data_formatted %>%
        ggplot2::ggplot(ggplot2::aes(!! date_var_expr, observed)) +
        ggplot2::labs(x = .x_lab, y = .y_lab, title = .title, color = .color_lab) +
        theme_tq()

    # Add facets
    if (length(facet_names) > 0) {
        g <- g +
            ggplot2::facet_wrap(
                ggplot2::vars(!!! rlang::syms(facet_names)),
                ncol   = .facet_ncol,
                scales = .facet_scales
            )
    }

    # Add Ribbon
    g <- g +
        ggplot2::geom_ribbon(ggplot2::aes(ymin = recomposed_l1, ymax = recomposed_l2),
                             fill = .ribbon_fill, alpha = .ribbon_alpha)


    # Add line
    g <- g +
        ggplot2::geom_line(
            color    = .line_color,
            size     = .line_size,
            linetype = .line_type,
            alpha    = .line_alpha
        )

    # Add Outliers
    g <- g +
        ggplot2::geom_point(ggplot2::aes_string(color = "anomaly"), size = .anom_size, alpha = .anom_alpha,
                            data = . %>% dplyr::filter(anomaly == "Yes")) +
        ggplot2::scale_color_manual(values = c("Yes" = .anom_color))

    # Show Legend?
    if (!.legend_show) {
        g <- g +
            ggplot2::theme(legend.position = "none")
    }

    # Convert to interactive if selected
    if (.interactive) {
        p <- plotly::ggplotly(g, dynamicTicks = TRUE)
        return(p)
    } else {
        return(g)
    }
}

#' @export
plot_anomaly_diagnostics.grouped_df <- function(.data, .date_var, .value, .facet_vars = NULL,

                                                .frequency = "auto", .trend = "auto",
                                                .alpha = 0.05, .max_anomalies = 0.2,
                                                .message = TRUE,

                                                .facet_ncol = 1, .facet_scales = "free",

                                                .line_color = "#2c3e50", .line_size = 0.5,
                                                .line_type = 1, .line_alpha = 1,

                                                .anom_color = "#e31a1c",
                                                .anom_alpha = 1, .anom_size = 1.5,

                                                .ribbon_fill = "grey20", .ribbon_alpha = 0.20,

                                                .legend_show = TRUE,

                                                .title = "Anomaly Diagnostics",
                                                .x_lab = "", .y_lab = "",
                                                .color_lab = "Anomaly",

                                                .interactive = TRUE) {


    # Tidy Eval Setup
    group_names   <- dplyr::group_vars(.data)
    facets_expr   <- rlang::enquos(.facet_vars)

    # Checks
    facet_names <- .data %>% dplyr::ungroup() %>% dplyr::select(!!! facets_expr) %>% colnames()
    if (length(facet_names) > 0) message("plot_anomaly_diagnostics(...): Groups are previously detected. Grouping by: ",
                                         stringr::str_c(group_names, collapse = ", "))

    # ---- DATA SETUP ----

    # Ungroup Data
    data_formatted <- .data %>% dplyr::ungroup()

    # ---- PLOT SETUP ----
    plot_anomaly_diagnostics.data.frame(
        .data               = data_formatted,
        .date_var           = !! rlang::enquo(.date_var),
        .value              = !! rlang::enquo(.value),

        # ...
        # !!! rlang::syms(group_names),
        .facet_vars         = !! enquo(group_names),

        .frequency          = .frequency,
        .trend              = .trend,
        .alpha              = .alpha,
        .max_anomalies      = .max_anomalies,
        .message            = .message,

        .facet_ncol         = .facet_ncol,
        .facet_scales       = .facet_scales,

        .line_color         = .line_color,
        .line_size          = .line_size,
        .line_type          = .line_type,
        .line_alpha         = .line_alpha,

        .anom_color         = .anom_color,
        .anom_alpha         = .anom_alpha,
        .anom_size          = .anom_size,

        .ribbon_fill        = .ribbon_fill,
        .ribbon_alpha       = .ribbon_alpha,

        .legend_show        = .legend_show,

        .title              = .title,
        .x_lab              = .x_lab,
        .y_lab              = .y_lab,
        .color_lab          = .color_lab,

        .interactive        = .interactive
    )

}
