using Plots

@userplot LogoAnimation
@recipe function f(logo::LogoAnimation; background_color = "#bbb")
    i, r, horizon, plot_info, line_info, planet_info = logo.args
    idx = max(1, i - horizon):i
    n = length(idx)

    aspect_ratio --> 1
    label --> false
    axis --> ([], false)
    legend --> false

    width --> 500
    x_lims --> plot_info.x_lims
    y_lims --> plot_info.y_lims
    background_color --> background_color

    @series begin
        seriestype := :path
        linewidth := n > 1 ? range(0, line_info.width, length = n) : line_info.width
        seriesalpha := n > 1 ? range(0, 1, length = n) : 1
        color --> line_info.color
        r[idx, 1], r[idx, 2]
    end

    @series begin
        seriestype := :scatter
        markerstrokewidth --> 0
        markersize --> planet_info.markersize
        markercolor --> planet_info.markercolor
        r[idx[end], 1:1], r[idx[end], 2:2]
    end
end
