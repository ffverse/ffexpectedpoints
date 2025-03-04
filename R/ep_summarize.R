#' Summarize EP
#'
#' This function summarizes the EP data up to the game level
#'
#' @param predicted_pbp list with dataframes created by `ep_predict`
#' @param stat_type options to limit the columns returned by `ep_summarize` - available options are "all", "expected_points", and "team stats"
#'
#' @examples
#' \donttest{
#' try({
#'   predicted <- readRDS(system.file("ep_predicted.rds",package = "ffopportunity"))
#'   # equivalent to nflreadr::load_pbp(2021) %>% head(100) %>% ep_preprocess() %>% ep_predict()
#'   ep_summarize(predicted)
#' })
#' }
#'
#' @return a dataframe with the expected points fields added
#'
#' @seealso `vignette("basic")` for example usage
#'
#' @export

ep_summarize <- function(predicted_pbp, stat_type = c("all", "expected_points", "team_stats")){

  stat_type <- rlang::arg_match(stat_type)

  where <- NULL

  rush_df <-
    predicted_pbp$rush_df %>%
    dplyr::transmute(
      season = substr(.data$game_id, 1, 4),
      .data$week,
      .data$game_id,
      play_id = as.factor(.data$play_id),
      play_description = .data$desc,
      player_id = .data$rusher_player_id,
      .data$full_name,
      .data$position,
      .data$posteam,
      player_type = "rush",
      attempt = dplyr::if_else(.data$two_point_attempt == 1, 0, .data$rush_attempt),
      yards_gained = .data$rushing_yards, #already 0 for 2pt attempts
      yards_gained_exp = dplyr::if_else(.data$two_point_attempt == 1, 0, .data$rush_yards_exp),
      touchdown = dplyr::if_else(.data$rush_touchdown == "1", 1L, 0L),
      touchdown_exp = dplyr::if_else(.data$two_point_attempt == 1, 0, .data$rush_touchdown_exp),
      two_point_conv = .data$two_point_converted,
      two_point_conv_exp = dplyr::if_else(.data$two_point_attempt == 1, .data$two_point_conv_exp, 0),
      first_down = .data$first_down_rush,
      first_down_exp = dplyr::if_else(.data$two_point_attempt == 1, 0, .data$rush_first_down_exp),
      fantasy_points =
        6.0 * .data$touchdown +
        2.0 * .data$two_point_converted +
        0.1 * .data$rushing_yards +
       -2.0 * .data$fumble_lost,
      fantasy_points_exp =
        0.1*.data$rush_yards_exp +
        dplyr::if_else(.data$two_point_attempt == 1, 2*.data$two_point_conv_exp, 6*.data$rush_touchdown_exp),
      .data$fumble_lost)

  pass_df <-
    predicted_pbp$pass_df %>%
    dplyr::transmute(
      season = substr(.data$game_id, 1, 4),
      .data$week,
      .data$game_id,
      play_id = as.factor(.data$play_id),
      play_description = .data$desc,
      .data$posteam,
      pass.player_id = .data$passer_player_id,
      pass.full_name = .data$passer_full_name,
      pass.position = .data$passer_position,
      rec.player_id = .data$receiver_player_id,
      rec.full_name = .data$receiver_full_name,
      rec.position = .data$receiver_position,
      .data$posteam,
      attempt = dplyr::if_else(.data$two_point_attempt == 1, 0, .data$pass_attempt),
      air_yards = dplyr::if_else(.data$two_point_attempt == 1, 0, .data$air_yards),
      complete_pass = dplyr::if_else(.data$complete_pass == "1", 1L, 0L),
      complete_pass_exp = dplyr::if_else(.data$two_point_attempt == 1, 0, .data$pass_completion_exp),
      #already 0 for 2pt attempts
      yards_gained = dplyr::if_else(is.na(.data$receiving_yards), 0, .data$receiving_yards),
      yards_gained_exp = .data$complete_pass_exp * (.data$yards_after_catch_exp + .data$air_yards),
      touchdown = dplyr::if_else(.data$pass_touchdown == "1", 1L, 0L),
      touchdown_exp = dplyr::if_else(.data$two_point_attempt == 1, 0, .data$pass_touchdown_exp),
      two_point_conv = .data$two_point_converted,
      two_point_conv_exp = dplyr::if_else(.data$two_point_attempt == 1, .data$two_point_conv_exp, 0),
      first_down = .data$first_down_pass,
      first_down_exp = dplyr::if_else(.data$two_point_attempt == 1, 0, .data$pass_first_down_exp),
      interception = dplyr::if_else(.data$interception == "1", 1L, 0L),
      interception_exp = dplyr::if_else(.data$two_point_attempt == 1, 0, .data$pass_interception_exp),
      .data$fumble_lost
    ) %>%
    tidyr::pivot_longer(
      cols = c(.data$pass.player_id,
               .data$pass.full_name,
               .data$pass.position,
               .data$rec.player_id,
               .data$rec.full_name,
               .data$rec.position),
      names_to = c("player_type", ".value"),
      names_sep = "\\.") %>%
    dplyr::mutate(
      fantasy_points_exp = dplyr::if_else(.data$player_type == "rec",
                                          0.1  * .data$yards_gained_exp +
                                          1    * .data$complete_pass_exp +
                                          6    * .data$touchdown_exp +
                                          2    * .data$two_point_conv_exp,
                                          0.04 * .data$yards_gained_exp +
                                        - 2    * .data$interception_exp +
                                          4    * .data$touchdown_exp +
                                          2    *.data$two_point_conv_exp),
      fantasy_points =     dplyr::if_else(.data$player_type == "rec",
                                          6    * .data$touchdown +
                                          2    * .data$two_point_conv  +
                                          0.1  * .data$yards_gained +
                                         -2    * .data$fumble_lost +
                                          1    * .data$complete_pass,
                                          4    * .data$touchdown +
                                          2    * .data$two_point_conv  +
                                          0.04 * .data$yards_gained +
                                         -2   *.data$interception
                                          # Haven't included sack fumbles yet
                                          # 2*.data$fumble_lost -
      ))

  combined_df <-
    pass_df %>%
    dplyr::bind_rows(rush_df) %>%
    tidyr::pivot_wider(
      id_cols = c(.data$season,
                  .data$posteam,
                  .data$week,
                  .data$game_id,
                  .data$player_id,
                  .data$full_name,
                  .data$position),
      names_from = .data$player_type,
      names_glue = "{player_type}_{.value}",
      values_fn = sum,
      values_from = c(where(is.numeric),-.data$week)) %>%
    janitor::remove_empty(which = "cols") %>%
    dplyr::mutate(dplyr::across(.cols = where(is.numeric), .fns =  ~tidyr::replace_na(.x, 0) %>% round(2))) %>%
    dplyr::mutate(
      total_yards_gained = .data$rec_yards_gained + .data$rush_yards_gained + .data$pass_yards_gained,
      total_yards_gained_exp = .data$rec_yards_gained_exp + .data$rush_yards_gained_exp + .data$pass_yards_gained_exp,
      total_touchdown = .data$rec_touchdown + .data$rush_touchdown + .data$pass_touchdown,
      total_touchdown_exp = .data$rec_touchdown_exp + .data$rush_touchdown_exp + .data$pass_touchdown_exp,
      total_first_down = .data$rec_first_down + .data$rush_first_down + .data$pass_first_down,
      total_first_down_exp = .data$rec_first_down_exp + .data$rush_first_down_exp + .data$pass_first_down_exp,
      total_fantasy_points = .data$rec_fantasy_points + .data$rush_fantasy_points + .data$pass_fantasy_points,
      total_fantasy_points_exp = .data$rec_fantasy_points_exp + .data$rush_fantasy_points_exp + .data$pass_fantasy_points_exp) %>%
    dplyr::ungroup() %>%
    dplyr::rename(
      pass_completions = .data$pass_complete_pass,
      pass_completions_exp = .data$pass_complete_pass_exp,
      receptions = .data$rec_complete_pass,
      receptions_exp = .data$rec_complete_pass_exp
    ) %>%
    # Haven't included sack fumbles yet
    dplyr::select(-.data$pass_fumble_lost)


  exp_fields <-
    combined_df %>%
    dplyr::select(tidyselect::ends_with("exp")) %>%
    colnames() %>%
    stringr::str_remove_all("_exp")

  for(f in exp_fields) {
    combined_df[paste0(f,"_diff")] <- combined_df[f]-combined_df[paste0(f,"_exp")]
  }

  team_df <-
    combined_df %>%
    dplyr::group_by(.data$season, .data$posteam, .data$week, .data$game_id) %>%
    dplyr::summarise(
      dplyr::across(.cols = where(is.numeric) & !contains("total"), .fns = sum, .names = "{col}_team"),
      total_yards_gained_team = .data$rec_yards_gained_team + .data$rush_yards_gained_team,
      total_yards_gained_exp_team = .data$rec_yards_gained_exp_team + .data$rush_yards_gained_exp_team,
      total_yards_gained_diff_team = .data$rec_yards_gained_diff_team + .data$rush_yards_gained_diff_team,

      total_touchdown_team = .data$rec_touchdown_team + .data$rush_touchdown_team,
      total_touchdown_exp_team = .data$rec_touchdown_exp_team + .data$rush_touchdown_exp_team,
      total_touchdown_diff_team = .data$rec_touchdown_diff_team + .data$rush_touchdown_diff_team,

      total_first_down_team = .data$rec_first_down_team + .data$rush_first_down_team,
      total_first_down_exp_team = .data$rec_first_down_exp_team + .data$rush_first_down_exp_team,
      total_first_down_diff_team = .data$rec_first_down_diff_team + .data$rush_first_down_diff_team,
      total_fantasy_points_team = .data$rec_fantasy_points_team + .data$rush_fantasy_points_team,
      total_fantasy_points_exp_team = .data$rec_fantasy_points_exp_team + .data$rush_fantasy_points_exp_team,
      total_fantasy_points_diff_team = .data$rec_fantasy_points_diff_team + .data$rush_fantasy_points_diff_team
    ) %>%
    dplyr::ungroup()

  player_team_df <-
    combined_df %>%
    dplyr::left_join(team_df, by = c("season", "posteam", "week", "game_id"))

  switch(
    stat_type,
    "all" = return(player_team_df),
    "expected_points" = return(combined_df),
    "team_stats" = return(team_df)
  )
}
