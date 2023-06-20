const path = require("path");
const common = require("./webpack.common.js");
const { merge } = require("webpack-merge");
const TerserPlugin = require("terser-webpack-plugin");
const CopyWebpackPlugin = require("copy-webpack-plugin");

module.exports = merge(common, {
  mode: "production",
  output: {
    filename: "[name].[contenthash].bundle.js",
  },
  plugins: [
    new CopyWebpackPlugin({
      patterns: [{ from: "assets" }],
    }),
  ],
  module: {
    rules: [
      {
        test: /\.elm$/,
        include: path.resolve(__dirname, "src"),
        use: [
          {
            loader: "elm-webpack-loader",
            options: {
              debug: false,
              optimize: true,
            },
          },
        ],
      },
    ],
  },
  optimization: {
    moduleIds: "deterministic",
    runtimeChunk: {
      name: "manifest",
    },
    splitChunks: {
      cacheGroups: {
        vendor: {
          test: /[\\/]node_modules[\\/]/,
          name: "vendors",
          chunks: "all",
        },
      },
    },
    minimize: true,
    minimizer: [
      new TerserPlugin({
        terserOptions: {
          warnings: false,
          parse: {},
          compress: {
            pure_funcs: "F2,F3,F4,F5,F6,F7,F8,F9,A2,A3,A4,A5,A6,A7,A8,A9",
            pure_getters: true,
            keep_fargs: false,
            unsafe_comps: true,
            unsafe: true,
          },
          mangle: true,
          output: null,
          toplevel: false,
          nameCache: null,
          ie8: false,
          keep_fnames: false,
        },
      }),
    ],
  },
});
