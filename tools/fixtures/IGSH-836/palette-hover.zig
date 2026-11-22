            if (app_state.g_search_active and (wp & MK_LBUTTON) == 0) {
                if (searchResultRowAtClientPoint(GET_X(lp), GET_Y(lp))) |hovered_row| {
                    if (hovered_row != app_state.g_search_sel and !paletteRowIsHeader(app_state.g_search_results[hovered_row])) {
                        app_state.g_search_sel = hovered_row;
                        _ = InvalidateRect(hwnd, null, 0);
                    }
                    return 0;
                }
            }
