const path = require("path");
const common = require("./webpack.common.js");
const { merge } = require("webpack-merge");

module.exports = merge(common, {
  mode: "development",
  devServer: {
    hot: "only",
    client: {
      logging: "info",
    },
    static: { directory: path.join(__dirname, "assets") },
  },
  module: {
    rules: [
      {
        test: /\.elm$/,
        include: path.resolve(__dirname, "src"),
        use: [
          {
            loader: "elm-webpack-loader",
            options: {
              verbose: true,
              debug: false,
              optimize: false,
            },
          },
        ],
      },
    ],
  },
});
