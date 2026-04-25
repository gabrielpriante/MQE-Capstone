# =============================================================================
# Program Health Dashboard — Public Skeleton Replica
# University of Pittsburgh (Pitt Blue #003594, Pitt Gold #FFB81C)
#
# This is a portfolio demonstration of a config-driven, multi-domain
# scoring dashboard. All data is synthetic. Architecture, scoring
# methodology, and UI patterns are the point — not the numbers.
#
# The dashboard reads ONE file: data/pipeline_output.json
# It NEVER calls Python. This is "the sacred wall."
#
# Tech: R Shiny + bslib (flatly) + Plotly + DT
# =============================================================================

library(shiny)
library(bslib)
library(jsonlite)
library(plotly)
library(DT)

# =============================================================================
# DATA LOAD — One file, one read, done.
# =============================================================================

json_path <- file.path(getwd(), "data", "pipeline_output.json")
if (!file.exists(json_path)) {
  json_path <- file.path(dirname(sys.frame(1)$ofile %||% "."), "data", "pipeline_output.json")
}
pipeline <- fromJSON(json_path, simplifyVector = FALSE)

programs  <- pipeline$programs
scoring   <- pipeline$scoring
context   <- pipeline$context
benchmarks <- pipeline$benchmarks
rankings  <- pipeline$rankings
ipeds     <- pipeline$ipeds
metadata  <- pipeline$metadata

# Program keys (exclude any informational-only like SS)
scored_keys  <- names(scoring$programs)
program_keys <- scored_keys
all_keys     <- names(programs)

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

PITT_BLUE <- "#003594"
PITT_GOLD <- "#FFB81C"

signal_color <- function(sig) {
  switch(sig, "green" = "#28a745", "yellow" = "#ffc107", "red" = "#dc3545", "#6c757d")
}

signal_icon <- function(sig) {
  switch(sig, "green" = "\U0001f7e2", "yellow" = "\U0001f7e1", "red" = "\U0001f534", "\u26aa")
}

fmt_dollar <- function(x) {
  if (is.null(x) || is.na(x)) return("N/A")
  if (abs(x) >= 1e6) return(paste0("$", formatC(x / 1e6, format = "f", digits = 1), "M"))
  if (abs(x) >= 1e3) return(paste0("$", formatC(x / 1e3, format = "f", digits = 0), "K"))
  paste0("$", formatC(x, format = "f", digits = 0, big.mark = ","))
}

fmt_num <- function(x, digits = 0) {
  if (is.null(x) || is.na(x)) return("N/A")
  formatC(x, format = "f", digits = digits, big.mark = ",")
}

fmt_pct <- function(x, digits = 1) {
  if (is.null(x) || is.na(x)) return("N/A")
  paste0(formatC(x, format = "f", digits = digits), "%")
}

fmt_k <- function(x) {
  if (is.null(x) || is.na(x)) return("N/A")
  paste0(formatC(x, format = "f", digits = 1), "K")
}

get_signal <- function(score, green_t, yellow_t) {
  if (is.null(score) || is.na(score)) return("red")
  if (score >= green_t) return("green")
  if (score >= yellow_t) return("yellow")
  return("red")
}

# Map for nice dimension names
DIM_LABELS <- c(
  projected_growth = "Projected Growth",
  annual_openings  = "Annual Openings",
  median_wage      = "Median Wage",
  separation_rate  = "Separation Rate",
  supply_ratio     = "Supply Ratio",
  skill_intensity  = "Skill Intensity",
  enrollment_trend = "Enrollment Trend",
  gross_tuition    = "Gross Tuition",
  revenue_per_student = "Revenue/Student",
  net_income       = "Net Income",
  cost_efficiency  = "Cost Efficiency"
)

DEMAND_DIMS <- c("projected_growth", "annual_openings", "median_wage",
                 "separation_rate", "supply_ratio", "skill_intensity")
INST_DIMS   <- c("enrollment_trend", "gross_tuition", "revenue_per_student")
FIN_DIMS    <- c("net_income", "cost_efficiency")

# =============================================================================
# UI
# =============================================================================

ui <- page_navbar(
  title = tags$span(
    tags$img(src = "https://upload.wikimedia.org/wikipedia/commons/thumb/5/53/Pitt_shield.svg/200px-Pitt_shield.svg.png",
             height = "28px", style = "margin-right:8px; vertical-align:middle;"),
    "Program Health Dashboard"
  ),
  id = "main_nav",
  theme = bs_theme(
    bootswatch = "flatly",
    primary = PITT_BLUE,
    "navbar-bg" = PITT_BLUE,
    "navbar-dark-color" = "white"
  ),
  header = tags$head(tags$style(HTML(sprintf("
    .navbar { background-color: %s !important; }
    .navbar-brand, .nav-link { color: white !important; }
    .nav-link.active { font-weight: bold; border-bottom: 3px solid %s; }
    .signal-tile { border-radius: 8px; padding: 16px; margin: 8px;
      cursor: pointer; transition: transform 0.15s; min-width: 160px; }
    .signal-tile:hover { transform: scale(1.03); box-shadow: 0 4px 12px rgba(0,0,0,0.15); }
    .domain-badge { display: inline-block; padding: 4px 10px; border-radius: 12px;
      font-size: 0.8rem; font-weight: 600; margin: 2px; }
    .metric-card { background: #f8f9fa; border-radius: 8px; padding: 14px;
      margin-bottom: 8px; border-left: 4px solid %s; }
    .compare-progs .checkbox { margin-bottom: 6px; }
  ", PITT_BLUE, PITT_GOLD, PITT_BLUE)))),

  # ── Tab 1: Overview ──
  nav_panel("Overview",
    layout_sidebar(
      sidebar = sidebar(
        title = "Controls",
        width = 280,
        sliderInput("green_threshold", "Green Threshold",
          min = 50, max = 90, value = scoring$config$thresholds$green, step = 5),
        sliderInput("yellow_threshold", "Yellow Threshold",
          min = 20, max = 60, value = scoring$config$thresholds$yellow, step = 5),
        tags$hr(),
        checkboxInput("benchmark_mode", "Benchmark Mode", FALSE),
        conditionalPanel(
          condition = "input.benchmark_mode == true",
          selectInput("benchmark_prog", "Benchmark Program",
            choices = setNames(program_keys,
              sapply(program_keys, function(k) scoring$programs[[k]]$full_name)),
            selected = program_keys[1])
        ),
        tags$hr(),
        tags$p(style = "font-size:.75rem;color:#999;",
          paste("Dashboard Skeleton |",
                "Pipeline v", metadata$pipeline_version)),
        tags$p(style = "font-size:.75rem;color:#999;",
          "Scoring: Demand 50% | Institutional 30% | Financial 20%"),
        tags$p(style = "font-size:.75rem;color:#999;",
          paste("Generated:", substr(metadata$generated_at, 1, 10)))
      ),
      uiOutput("overview_tiles"),
      tags$hr(),
      tags$h5("Dimension Heatmap"),
      plotlyOutput("heatmap", height = "420px")
    )
  ),

  # ── Tab 2: Program Detail ──
  nav_panel("Program Detail",
    layout_sidebar(
      sidebar = sidebar(
        title = "Select Program",
        width = 280,
        selectInput("detail_prog", "Program",
          choices = setNames(all_keys,
            sapply(all_keys, function(k) programs[[k]]$full_name)),
          selected = program_keys[1])
      ),
      uiOutput("detail_header"),
      tags$hr(),
      fluidRow(
        column(6, plotlyOutput("detail_domain_bars", height = "320px")),
        column(6, plotlyOutput("detail_dimension_bars", height = "320px"))
      ),
      tags$hr(),
      fluidRow(
        column(6,
          tags$h5("Enrollment Trend"),
          plotlyOutput("detail_enrollment", height = "280px")
        ),
        column(6,
          tags$h5("Revenue vs Expense (FY26 Budget)"),
          plotlyOutput("detail_financial", height = "280px")
        )
      ),
      tags$hr(),
      fluidRow(
        column(6,
          tags$h5("BLS Projections"),
          uiOutput("detail_bls_card")
        ),
        column(6,
          tags$h5("Skills Profile"),
          plotlyOutput("detail_skills", height = "280px")
        )
      )
    )
  ),

  # ── Tab 3: Compare ──
  nav_panel("Compare",
    layout_sidebar(
      sidebar = sidebar(
        title = "Compare Programs",
        width = 280,
        tags$style(".compare-progs .checkbox { margin-bottom: 6px; }"),
        tags$div(class = "compare-progs",
          checkboxGroupInput("compare_progs", "Select Programs",
            choices = setNames(program_keys,
              sapply(program_keys, function(k)
                paste0(k, " \u2014 ", scoring$programs[[k]]$full_name))),
            selected = program_keys)
        ),
        tags$p(style = "font-size:.75rem;color:#999;margin-top:12px;",
          "\U0001f50d Click any chart to expand it.")
      ),
      fluidRow(
        column(6,
          tags$div(id = "zoom_compare_demand",
            style = "cursor:pointer;",
            onclick = "Shiny.setInputValue('zoom_chart', 'compare_demand', {priority: 'event'});",
            tags$h5("Demand Dimension Scores"),
            plotlyOutput("compare_demand", height = "320px")
          )
        ),
        column(6,
          tags$div(id = "zoom_compare_domains",
            style = "cursor:pointer;",
            onclick = "Shiny.setInputValue('zoom_chart', 'compare_domains', {priority: 'event'});",
            tags$h5("Domain Score Breakdown"),
            plotlyOutput("compare_domains", height = "320px")
          )
        )
      ),
      tags$hr(),
      fluidRow(
        column(6,
          tags$div(id = "zoom_compare_enrollment",
            style = "cursor:pointer;",
            onclick = "Shiny.setInputValue('zoom_chart', 'compare_enrollment', {priority: 'event'});",
            tags$h5("Enrollment Trend (AY21\u2013AY25)"),
            plotlyOutput("compare_enrollment", height = "320px")
          )
        ),
        column(6,
          tags$div(id = "zoom_compare_financial",
            style = "cursor:pointer;",
            onclick = "Shiny.setInputValue('zoom_chart', 'compare_financial', {priority: 'event'});",
            tags$h5("Revenue vs Expense"),
            plotlyOutput("compare_financial", height = "320px")
          )
        )
      )
    )
  ),

  # ── Tab 4: Leaderboard ──
  nav_panel("Leaderboard",
    tags$h4("Program Rankings"),
    DTOutput("leaderboard_table"),
    tags$hr(),
    tags$h4("External Rankings"),
    uiOutput("rankings_section")
  ),

  # ── Tab 5: Supply Analysis ──
  nav_panel("Supply Analysis",
    layout_sidebar(
      sidebar = sidebar(
        title = "Supply Controls",
        width = 280,
        selectInput("supply_prog", "Program Detail",
          choices = setNames(program_keys,
            sapply(program_keys, function(k) scoring$programs[[k]]$full_name)),
          selected = program_keys[1])
      ),
      tags$h4("National Supply vs Demand"),
      fluidRow(
        column(6,
          tags$div(
            style = "cursor:pointer;",
            onclick = "Shiny.setInputValue('zoom_chart', 'supply_ratio', {priority: 'event'});",
            plotlyOutput("supply_ratio_chart", height = "360px")
          )
        ),
        column(6,
          tags$div(
            style = "cursor:pointer;",
            onclick = "Shiny.setInputValue('zoom_chart', 'supply_trend', {priority: 'event'});",
            plotlyOutput("supply_trend_chart", height = "360px")
          )
        )
      ),
      tags$hr(),
      uiOutput("supply_detail_card")
    )
  )
)

# =============================================================================
# SERVER
# =============================================================================

server <- function(input, output, session) {

  # ── Reactive: recompute signals when thresholds change ──
  rv_scores <- reactive({
    gt <- input$green_threshold
    yt <- input$yellow_threshold
    bm <- input$benchmark_mode
    bm_prog <- input$benchmark_prog

    scores <- list()
    for (key in program_keys) {
      sp <- scoring$programs[[key]]
      dims <- sp$dimensions

      # Recompute signals with new thresholds
      for (d in names(dims)) {
        sc <- dims[[d]]$score
        if (is.null(sc)) sc <- NA_real_
        dims[[d]]$signal <- get_signal(sc, gt, yt)
      }

      demand_score <- if (is.null(sp$demand$score)) 0 else sp$demand$score
      inst_score   <- if (is.null(sp$institutional$score)) 0 else sp$institutional$score
      fin_score    <- if (is.null(sp$financial$score)) 0 else sp$financial$score
      comp_score   <- if (is.null(sp$composite$score)) 0 else sp$composite$score

      # Benchmark mode: normalize to selected program
      if (bm && !is.null(bm_prog)) {
        bm_sp <- scoring$programs[[bm_prog]]
        bm_comp <- bm_sp$composite$score
        if (!is.null(bm_comp) && bm_comp > 0) {
          comp_score   <- round(comp_score / bm_comp * 100, 1)
          demand_score <- round(demand_score / (bm_sp$demand$score) * 100, 1)
          inst_score   <- round(inst_score / (bm_sp$institutional$score) * 100, 1)
          fin_score    <- round(fin_score / (bm_sp$financial$score) * 100, 1)
        }
      }

      scores[[key]] <- list(
        key = key,
        full_name = sp$full_name,
        composite = comp_score,
        composite_signal = get_signal(
          if (bm) scoring$programs[[key]]$composite$score else comp_score, gt, yt),
        demand = demand_score,
        demand_signal = get_signal(
          if (bm) scoring$programs[[key]]$demand$score else demand_score, gt, yt),
        institutional = inst_score,
        institutional_signal = get_signal(
          if (bm) scoring$programs[[key]]$institutional$score else inst_score, gt, yt),
        financial = fin_score,
        financial_signal = get_signal(
          if (bm) scoring$programs[[key]]$financial$score else fin_score, gt, yt),
        rank = sp$composite$rank,
        dims = dims
      )
    }
    scores
  })

  # ── Overview Tiles ──
  output$overview_tiles <- renderUI({
    scores <- rv_scores()
    sorted_keys <- names(scores)[order(sapply(scores, function(s) s$rank))]

    tiles <- lapply(sorted_keys, function(key) {
      s <- scores[[key]]
      col <- signal_color(s$composite_signal)
      bg <- paste0(col, "15")
      label <- if (input$benchmark_mode) paste0(round(s$composite, 0), "%") else
        paste0(round(s$composite, 1), "/100")

      # Supply ratio badge
      spigot <- ipeds$spigot_summary[[key]]
      sr_badge <- ""
      if (!is.null(spigot) && !is.null(spigot$supply_ratio)) {
        sr_badge <- tags$span(
          style = "font-size:.7rem; background:#e9ecef; padding:2px 6px; border-radius:8px;",
          paste0("Supply: ", sprintf("%.2fx", spigot$supply_ratio))
        )
      }

      tags$div(
        class = "signal-tile",
        style = paste0("background:", bg, "; border:2px solid ", col, ";",
                        "display:inline-block; vertical-align:top; text-align:center;"),
        onclick = sprintf("Shiny.setInputValue('tile_click', '%s', {priority:'event'});", key),
        tags$div(style = "font-size:1.5rem; font-weight:bold;", paste0("#", s$rank)),
        tags$div(style = "font-weight:600; margin:4px 0;", s$full_name),
        tags$div(style = "font-size:.8rem; color:#666;", key),
        tags$div(style = paste0("font-size:1.3rem; font-weight:bold; color:", col, ";"), label),
        tags$div(
          tags$span(class = "domain-badge",
            style = paste0("background:", signal_color(s$demand_signal), "22; color:", signal_color(s$demand_signal), ";"),
            paste0("D:", round(s$demand, 1))),
          tags$span(class = "domain-badge",
            style = paste0("background:", signal_color(s$institutional_signal), "22; color:", signal_color(s$institutional_signal), ";"),
            paste0("I:", round(s$institutional, 1))),
          tags$span(class = "domain-badge",
            style = paste0("background:", signal_color(s$financial_signal), "22; color:", signal_color(s$financial_signal), ";"),
            paste0("F:", round(s$financial, 1)))
        ),
        sr_badge
      )
    })

    tags$div(style = "display:flex; flex-wrap:wrap; justify-content:center;", tiles)
  })

  # Navigate to detail on tile click
  observeEvent(input$tile_click, {
    updateSelectInput(session, "detail_prog", selected = input$tile_click)
    updateNavbarPage(session, "main_nav", selected = "Program Detail")
  })

  # ── Heatmap ──
  output$heatmap <- renderPlotly({
    scores <- rv_scores()
    all_dims <- c(DEMAND_DIMS, INST_DIMS, FIN_DIMS)
    sorted_keys <- names(scores)[order(sapply(scores, function(s) s$rank))]

    mat <- matrix(NA, nrow = length(all_dims), ncol = length(sorted_keys))
    text_mat <- matrix("", nrow = length(all_dims), ncol = length(sorted_keys))

    for (j in seq_along(sorted_keys)) {
      key <- sorted_keys[j]
      dims <- scores[[key]]$dims
      for (i in seq_along(all_dims)) {
        d <- all_dims[i]
        if (!is.null(dims[[d]])) {
          sc <- dims[[d]]$score
          if (is.null(sc)) sc <- NA_real_
          mat[i, j] <- sc
          rl <- dims[[d]]$raw_label
          if (is.null(rl)) rl <- "N/A"
          text_mat[i, j] <- paste0(rl, "\n", if (!is.na(sc)) paste0(round(sc, 1), "/100") else "N/A")
        }
      }
    }

    prog_labels <- sapply(sorted_keys, function(k) scores[[k]]$full_name)
    dim_labels <- sapply(all_dims, function(d) DIM_LABELS[[d]])

    plot_ly(x = prog_labels, y = dim_labels, z = mat, text = text_mat,
            type = "heatmap", hoverinfo = "text",
            colorscale = list(c(0, "#dc3545"), c(0.5, "#ffc107"), c(1, "#28a745")),
            zmin = 0, zmax = 100) %>%
      layout(margin = list(l = 140, b = 80),
             xaxis = list(title = "", tickangle = -45),
             yaxis = list(title = "", autorange = "reversed"))
  })

  # ── Program Detail Header ──
  output$detail_header <- renderUI({
    key <- input$detail_prog
    if (is.null(key) || !(key %in% all_keys)) return(NULL)
    prog <- programs[[key]]
    sp <- scoring$programs[[key]]

    if (is.null(sp)) {
      return(tags$div(
        tags$h3(prog$full_name),
        tags$p("This program is informational only — not scored or ranked.")
      ))
    }

    comp <- sp$composite
    sig <- comp$signal

    # Enrollment CAGR
    enr <- prog$enrollment$gross_tuition
    if (!is.null(enr) && length(enr$enrollment) >= 5) {
      e_start <- enr$enrollment[[1]]
      e_end   <- enr$enrollment[[5]]
      if (e_start > 0 && e_end > 0) {
        cagr <- ((e_end / e_start)^(1/4) - 1) * 100
        cagr_label <- paste0("Enrollment CAGR: ", fmt_pct(cagr))
      } else { cagr_label <- "Enrollment CAGR: N/A" }
    } else { cagr_label <- "Enrollment CAGR: N/A" }

    # Financial source
    fin <- prog$financials
    fin_label <- paste0("FY26 Budget: ", fmt_dollar(fin$gross_tuition),
                        " tuition \u2013 ", fmt_dollar(fin$total_expenses), " expense")

    tags$div(
      style = paste0("padding:16px; border-radius:8px; border-left:6px solid ",
                      signal_color(sig), "; background:", signal_color(sig), "10;"),
      fluidRow(
        column(8,
          tags$h3(paste0(prog$full_name, " (", key, ")")),
          tags$p(paste0(prog$department, " | ", prog$degree_level, " | SOC: ", prog$primary_soc)),
          tags$p(style = "font-size:.85rem; color:#666;", cagr_label),
          tags$p(style = "font-size:.85rem; color:#666;", fin_label)
        ),
        column(4, style = "text-align:right;",
          tags$div(style = paste0("font-size:2rem; font-weight:bold; color:", signal_color(sig), ";"),
            paste0(round(comp$score, 1), "/100")),
          tags$div(style = "font-size:1.1rem;",
            signal_icon(sig), paste0(" Rank #", comp$rank, " of ", length(program_keys)))
        )
      )
    )
  })

  # ── Detail: Domain Bars ──
  output$detail_domain_bars <- renderPlotly({
    key <- input$detail_prog
    sp <- scoring$programs[[key]]
    if (is.null(sp)) return(plot_ly() %>% layout(title = "Not scored"))

    domains <- c("Demand", "Institutional", "Financial", "Composite")
    vals <- c(sp$demand$score, sp$institutional$score, sp$financial$score, sp$composite$score)
    colors <- sapply(c(sp$demand$signal, sp$institutional$signal,
                       sp$financial$signal, sp$composite$signal), signal_color)

    plot_ly(x = vals, y = domains, type = "bar", orientation = "h",
            marker = list(color = colors),
            text = paste0(round(vals, 1), "/100"), textposition = "outside") %>%
      layout(xaxis = list(title = "Score", range = c(0, 105)),
             yaxis = list(title = ""), margin = list(l = 100),
             title = "Domain Scores")
  })

  # ── Detail: Dimension Bars ──
  output$detail_dimension_bars <- renderPlotly({
    key <- input$detail_prog
    sp <- scoring$programs[[key]]
    if (is.null(sp)) return(plot_ly())

    dims <- sp$dimensions
    all_d <- c(DEMAND_DIMS, INST_DIMS, FIN_DIMS)
    labels <- sapply(all_d, function(d) DIM_LABELS[[d]])
    vals <- sapply(all_d, function(d) if (!is.null(dims[[d]])) dims[[d]]$score else 0)
    colors <- sapply(all_d, function(d) {
      if (!is.null(dims[[d]])) signal_color(dims[[d]]$signal) else "#ccc"
    })

    plot_ly(x = vals, y = labels, type = "bar", orientation = "h",
            marker = list(color = colors),
            text = paste0(round(vals, 1)), textposition = "outside") %>%
      layout(xaxis = list(title = "Score (0-100)", range = c(0, 105)),
             yaxis = list(title = "", autorange = "reversed"),
             margin = list(l = 140), title = "Dimension Scores")
  })

  # ── Detail: Enrollment Trend ──
  output$detail_enrollment <- renderPlotly({
    key <- input$detail_prog
    prog <- programs[[key]]
    et <- prog$enrollment$et_series
    if (is.null(et)) return(plot_ly())

    plot_ly(x = et$years, y = unlist(et$headcount), type = "scatter", mode = "lines+markers",
            line = list(color = PITT_BLUE, width = 2),
            marker = list(color = PITT_BLUE, size = 6)) %>%
      layout(xaxis = list(title = "Fall Term"),
             yaxis = list(title = "Headcount"))
  })

  # ── Detail: Financial ──
  output$detail_financial <- renderPlotly({
    key <- input$detail_prog
    fin <- programs[[key]]$financials
    if (is.null(fin)) return(plot_ly())

    cats <- c("Tuition", "Expenses", "Net Income")
    vals <- c(fin$gross_tuition, fin$total_expenses, fin$net_income)
    colors <- c(PITT_BLUE, PITT_GOLD, if (fin$net_income >= 0) "#28a745" else "#dc3545")

    plot_ly(x = cats, y = vals, type = "bar",
            marker = list(color = colors),
            text = sapply(vals, fmt_dollar), textposition = "outside") %>%
      layout(yaxis = list(title = "Dollars"),
             xaxis = list(title = ""))
  })

  # ── Detail: BLS Card ──
  output$detail_bls_card <- renderUI({
    key <- input$detail_prog
    proj <- programs[[key]]$projection
    if (is.null(proj)) return(tags$p("No BLS data available."))

    tags$div(class = "metric-card",
      tags$p(tags$strong("Occupation: "), proj$title),
      tags$p(tags$strong("SOC: "), proj$soc_code),
      tags$p(tags$strong("Growth (2024\u201334): "), fmt_pct(proj$growth_percent)),
      tags$p(tags$strong("Annual Openings: "), fmt_k(proj$annual_openings)),
      tags$p(tags$strong("Median Wage: "), fmt_dollar(proj$median_wage)),
      tags$p(tags$strong("Typical Education: "), proj$typical_education),
      tags$p(tags$strong("Work Experience: "), proj$work_experience),
      tags$p(tags$strong("OJT: "), proj$on_the_job_training)
    )
  })

  # ── Detail: Skills Radar ──
  output$detail_skills <- renderPlotly({
    key <- input$detail_prog
    sk <- programs[[key]]$skills
    if (is.null(sk) || is.null(sk$ep_scores)) return(plot_ly())

    scores_list <- sk$ep_scores
    names_list <- names(scores_list)
    vals <- unlist(scores_list)

    plot_ly(type = "scatterpolar", mode = "lines+markers",
            r = c(vals, vals[1]), theta = c(names_list, names_list[1]),
            fill = "toself", fillcolor = paste0(PITT_BLUE, "33"),
            line = list(color = PITT_BLUE)) %>%
      layout(polar = list(radialaxis = list(range = c(0, 5))),
             margin = list(l = 60, r = 60))
  })

  # ── Compare: Demand Dimensions ──
  output$compare_demand <- renderPlotly({
    sel <- input$compare_progs
    if (is.null(sel) || length(sel) == 0) return(plot_ly())

    traces <- list()
    for (key in sel) {
      sp <- scoring$programs[[key]]
      vals <- sapply(DEMAND_DIMS, function(d) {
        if (!is.null(sp$dimensions[[d]])) sp$dimensions[[d]]$score else 0
      })
      traces[[key]] <- vals
    }

    dim_labels <- sapply(DEMAND_DIMS, function(d) DIM_LABELS[[d]])

    p <- plot_ly()
    for (key in sel) {
      p <- p %>% add_trace(x = dim_labels, y = traces[[key]], type = "bar",
                           name = key)
    }
    p %>% layout(barmode = "group",
                 yaxis = list(title = "Score (0-100)", range = c(0, 100)),
                 xaxis = list(title = ""),
                 legend = list(orientation = "h", y = -0.2))
  })

  # ── Compare: Domain Breakdown ──
  output$compare_domains <- renderPlotly({
    sel <- input$compare_progs
    if (is.null(sel) || length(sel) == 0) return(plot_ly())

    p <- plot_ly()
    domains <- c("demand", "institutional", "financial")
    colors <- c(PITT_BLUE, PITT_GOLD, "#28a745")

    for (i in seq_along(domains)) {
      dom <- domains[i]
      vals <- sapply(sel, function(k) scoring$programs[[k]][[dom]]$score)
      p <- p %>% add_trace(x = sel, y = vals, type = "bar",
                           name = tools::toTitleCase(dom),
                           marker = list(color = colors[i]))
    }

    if (input$benchmark_mode) {
      p <- p %>% add_trace(x = sel, y = rep(100, length(sel)),
                           type = "scatter", mode = "lines",
                           line = list(dash = "dash", color = "black", width = 1.5),
                           name = "Benchmark (100%)")
    }

    p %>% layout(barmode = "group",
                 yaxis = list(title = "Score"),
                 legend = list(orientation = "h", y = -0.2))
  })

  # ── Compare: Enrollment Trend ──
  output$compare_enrollment <- renderPlotly({
    sel <- input$compare_progs
    if (is.null(sel) || length(sel) == 0) return(plot_ly())

    p <- plot_ly()
    ay <- paste0("AY", 21:25)
    for (key in sel) {
      enr <- programs[[key]]$enrollment$gross_tuition$enrollment[1:5]
      p <- p %>% add_trace(x = ay, y = unlist(enr), type = "scatter",
                           mode = "lines+markers", name = key)
    }
    p %>% layout(yaxis = list(title = "Enrollment"),
                 xaxis = list(title = ""),
                 legend = list(orientation = "h", y = -0.2))
  })

  # ── Compare: Revenue vs Expense ──
  output$compare_financial <- renderPlotly({
    sel <- input$compare_progs
    if (is.null(sel) || length(sel) == 0) return(plot_ly())

    tuition <- sapply(sel, function(k) programs[[k]]$financials$gross_tuition)
    expense <- sapply(sel, function(k) programs[[k]]$financials$total_expenses)
    net     <- sapply(sel, function(k) programs[[k]]$financials$net_income)

    plot_ly() %>%
      add_trace(x = sel, y = tuition, type = "bar", name = "Tuition",
                marker = list(color = PITT_BLUE)) %>%
      add_trace(x = sel, y = expense, type = "bar", name = "Expense",
                marker = list(color = PITT_GOLD)) %>%
      add_trace(x = sel, y = net, type = "bar", name = "Net Income",
                marker = list(color = sapply(net, function(n)
                  if (n >= 0) "#28a745" else "#dc3545"))) %>%
      layout(barmode = "group",
             yaxis = list(title = "Dollars"),
             legend = list(orientation = "h", y = -0.2))
  })

  # ── Zoom Modal ──
  observeEvent(input$zoom_chart, {
    chart_id <- input$zoom_chart
    showModal(modalDialog(
      title = paste("Expanded View:", chart_id),
      size = "l", easyClose = TRUE,
      plotlyOutput("zoom_plot", height = "500px")
    ))
  })

  output$zoom_plot <- renderPlotly({
    chart_id <- input$zoom_chart
    sel <- input$compare_progs

    if (chart_id == "compare_demand") {
      p <- plot_ly()
      for (key in sel) {
        sp <- scoring$programs[[key]]
        vals <- sapply(DEMAND_DIMS, function(d)
          if (!is.null(sp$dimensions[[d]])) sp$dimensions[[d]]$score else 0)
        p <- p %>% add_trace(x = sapply(DEMAND_DIMS, function(d) DIM_LABELS[[d]]),
                             y = vals, type = "bar", name = key)
      }
      p %>% layout(barmode = "group", yaxis = list(range = c(0, 100)))

    } else if (chart_id == "compare_domains") {
      p <- plot_ly()
      for (i in seq_along(c("demand", "institutional", "financial"))) {
        dom <- c("demand", "institutional", "financial")[i]
        vals <- sapply(sel, function(k) scoring$programs[[k]][[dom]]$score)
        p <- p %>% add_trace(x = sel, y = vals, type = "bar",
                             name = tools::toTitleCase(dom),
                             marker = list(color = c(PITT_BLUE, PITT_GOLD, "#28a745")[i]))
      }
      p %>% layout(barmode = "group")

    } else if (chart_id == "compare_enrollment") {
      p <- plot_ly()
      ay <- paste0("AY", 21:25)
      for (key in sel) {
        enr <- programs[[key]]$enrollment$gross_tuition$enrollment[1:5]
        p <- p %>% add_trace(x = ay, y = unlist(enr), type = "scatter",
                             mode = "lines+markers", name = key)
      }
      p %>% layout(yaxis = list(title = "Enrollment"))

    } else if (chart_id == "compare_financial") {
      tuition <- sapply(sel, function(k) programs[[k]]$financials$gross_tuition)
      expense <- sapply(sel, function(k) programs[[k]]$financials$total_expenses)
      plot_ly() %>%
        add_trace(x = sel, y = tuition, type = "bar", name = "Tuition",
                  marker = list(color = PITT_BLUE)) %>%
        add_trace(x = sel, y = expense, type = "bar", name = "Expense",
                  marker = list(color = PITT_GOLD)) %>%
        layout(barmode = "group")

    } else if (chart_id == "supply_ratio") {
      keys_sorted <- program_keys[order(sapply(program_keys, function(k) {
        sr <- ipeds$spigot_summary[[k]]$supply_ratio
        if (is.null(sr)) 999 else sr
      }))]
      ratios <- sapply(keys_sorted, function(k) ipeds$spigot_summary[[k]]$supply_ratio)
      colors <- sapply(ratios, function(r) {
        if (is.null(r)) "#ccc" else if (r < 0.5) "#dc3545" else if (r < 1.0) "#ffc107" else "#28a745"
      })
      plot_ly(x = keys_sorted, y = ratios, type = "bar",
              marker = list(color = colors)) %>%
        add_trace(x = keys_sorted, y = rep(1, length(keys_sorted)),
                  type = "scatter", mode = "lines",
                  line = list(dash = "dash", color = "black"), name = "1:1 Balance") %>%
        layout(yaxis = list(title = "Supply Ratio (Grads/Openings)"))

    } else if (chart_id == "supply_trend") {
      p <- plot_ly()
      for (key in program_keys) {
        ts <- ipeds$spigot_summary[[key]]$trend_series
        if (!is.null(ts)) {
          p <- p %>% add_trace(x = names(ts), y = unlist(ts),
                               type = "scatter", mode = "lines+markers", name = key)
        }
      }
      p %>% layout(yaxis = list(title = "National Graduates"))

    } else {
      plot_ly() %>% layout(title = "Chart not found")
    }
  })

  # ── Leaderboard Table ──
  output$leaderboard_table <- renderDT({
    scores <- rv_scores()
    sorted_keys <- names(scores)[order(sapply(scores, function(s) s$rank))]

    safe_num <- function(x) { if (is.null(x) || length(x) == 0) NA_real_ else as.numeric(x) }

    df <- data.frame(
      Rank = vapply(sorted_keys, function(k) safe_num(scores[[k]]$rank), numeric(1)),
      Signal = vapply(sorted_keys, function(k) signal_icon(scores[[k]]$composite_signal), character(1)),
      Program = vapply(sorted_keys, function(k) as.character(scores[[k]]$full_name), character(1)),
      Composite = vapply(sorted_keys, function(k) round(safe_num(scores[[k]]$composite), 1), numeric(1)),
      Demand = vapply(sorted_keys, function(k) round(safe_num(scores[[k]]$demand), 1), numeric(1)),
      Institutional = vapply(sorted_keys, function(k) round(safe_num(scores[[k]]$institutional), 1), numeric(1)),
      Financial = vapply(sorted_keys, function(k) round(safe_num(scores[[k]]$financial), 1), numeric(1)),
      stringsAsFactors = FALSE
    )
    rownames(df) <- NULL

    datatable(df, options = list(
      pageLength = 15, dom = "t", ordering = TRUE,
      columnDefs = list(list(className = "dt-center", targets = "_all"))
    ), rownames = FALSE, escape = FALSE)
  })

  # ── Rankings Section ──
  output$rankings_section <- renderUI({
    ranked_progs <- rankings$programs
    cards <- lapply(names(ranked_progs), function(key) {
      r <- ranked_progs[[key]]
      if (is.null(r$ranked) || !r$ranked) return(NULL)

      top10 <- r$top_10
      top10_html <- lapply(top10, function(entry) {
        highlight <- grepl("Pittsburgh", entry$school, fixed = TRUE)
        style <- if (highlight) "font-weight:bold; color:#003594;" else ""
        tied <- if (!is.null(entry$tied) && entry$tied) " (T)" else ""
        tags$li(style = style,
          paste0("#", entry$rank, tied, " ", entry$school))
      })

      rank_label <- paste0("#", r$pitt_rank)
      if (!is.null(r$pitt_rank_tied) && r$pitt_rank_tied) rank_label <- paste0(rank_label, " (T)")

      prev <- ""
      if (!is.null(r$previous_rank)) {
        diff <- r$previous_rank - r$pitt_rank
        arrow <- if (diff > 0) paste0("\u2191", diff) else if (diff < 0) paste0("\u2193", abs(diff)) else "\u2194"
        prev <- paste0(" (was #", r$previous_rank, " ", arrow, ")")
      }

      tags$div(class = "metric-card", style = "margin-bottom:16px;",
        tags$h5(paste0(r$us_news_category)),
        tags$p(tags$strong("Pitt Rank: "), rank_label, prev),
        tags$p(tags$strong("Total Ranked: "), r$total_programs_ranked),
        tags$p(tags$strong("Top 10:")),
        tags$ol(style = "padding-left:20px; font-size:.85rem;", top10_html)
      )
    })

    not_ranked <- lapply(names(ranked_progs), function(key) {
      r <- ranked_progs[[key]]
      if (!is.null(r$ranked) && r$ranked) return(NULL)
      tags$p(style = "color:#999; font-size:.85rem;",
        paste0(programs[[key]]$full_name, " \u2014 Not ranked"))
    })

    tagList(cards, not_ranked)
  })

  # ── Supply: Ratio Chart ──
  output$supply_ratio_chart <- renderPlotly({
    keys_sorted <- program_keys[order(sapply(program_keys, function(k) {
      sr <- ipeds$spigot_summary[[k]]$supply_ratio
      if (is.null(sr)) 999 else sr
    }))]

    ratios <- sapply(keys_sorted, function(k) {
      sr <- ipeds$spigot_summary[[k]]$supply_ratio
      if (is.null(sr)) NA else sr
    })

    colors <- sapply(ratios, function(r) {
      if (is.na(r)) "#ccc"
      else if (r < 0.5) "#dc3545"
      else if (r < 1.0) "#ffc107"
      else "#28a745"
    })

    labels <- sapply(keys_sorted, function(k) scoring$programs[[k]]$full_name)

    plot_ly(x = labels, y = ratios, type = "bar",
            marker = list(color = colors),
            text = paste0(round(ratios, 2), "x"), textposition = "outside") %>%
      add_trace(x = labels, y = rep(1, length(labels)),
                type = "scatter", mode = "lines",
                line = list(dash = "dash", color = "black", width = 1.5),
                name = "1:1 Balance", showlegend = TRUE) %>%
      layout(title = "Supply Ratio by Program",
             yaxis = list(title = "Graduates / Openings"),
             xaxis = list(tickangle = -45),
             showlegend = FALSE,
             margin = list(b = 100))
  })

  # ── Supply: Trend Chart ──
  output$supply_trend_chart <- renderPlotly({
    p <- plot_ly()
    for (key in program_keys) {
      ts <- ipeds$spigot_summary[[key]]$trend_series
      if (!is.null(ts)) {
        p <- p %>% add_trace(x = names(ts), y = unlist(ts),
                             type = "scatter", mode = "lines+markers",
                             name = key)
      }
    }
    p %>% layout(title = "7-Year National Completions Trend",
                 yaxis = list(title = "Graduates"),
                 xaxis = list(title = "Academic Year"),
                 legend = list(orientation = "h", y = -0.3))
  })

  # ── Supply: Detail Card ──
  output$supply_detail_card <- renderUI({
    key <- input$supply_prog
    if (is.null(key)) return(NULL)

    spigot <- ipeds$spigot_summary[[key]]
    prog_ipeds <- programs[[key]]$ipeds
    prog_name <- programs[[key]]$full_name

    if (is.null(spigot)) return(tags$p("No IPEDS data available for this program."))

    # PA competitors table
    pa_comps <- prog_ipeds$pa_competitors
    pa_html <- NULL
    if (!is.null(pa_comps) && length(pa_comps) > 0) {
      rows <- lapply(pa_comps, function(c) {
        style <- if (!is.null(c$is_pitt) && c$is_pitt) "font-weight:bold; background:#003594; color:white;" else ""
        tags$tr(style = style,
          tags$td(c$pa_rank), tags$td(c$school), tags$td(c$city), tags$td(c$awards))
      })
      pa_html <- tags$div(
        tags$h6("State Competitors (IPEDS Completions)"),
        tags$table(class = "table table-sm table-striped", style = "font-size:.85rem;",
          tags$thead(tags$tr(
            tags$th("Rank"), tags$th("Institution"), tags$th("City"), tags$th("Awards"))),
          tags$tbody(rows)
        )
      )
    }

    tags$div(class = "metric-card",
      tags$h5(paste0(prog_name, " \u2014 Supply Detail")),
      fluidRow(
        column(3, tags$p(tags$strong("Latest Graduates")), tags$p(fmt_num(spigot$latest_graduates))),
        column(3, tags$p(tags$strong("BLS Openings")), tags$p(fmt_num(spigot$bls_annual_openings))),
        column(3, tags$p(tags$strong("Supply Ratio")), tags$p(paste0(sprintf("%.2f", spigot$supply_ratio), "x"))),
        column(3, tags$p(tags$strong("Trend")), tags$p(paste0(fmt_pct(spigot$trend_pct), " (", spigot$trend_start, "\u2013", spigot$trend_end, ")")))
      ),
      tags$hr(),
      pa_html
    )
  })
}

shinyApp(ui, server)
