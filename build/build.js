const path = require('path');
const { VueLoaderPlugin } = require('vue-loader')
const CopyPlugin = require("copy-webpack-plugin");
const BUILD_DIR = __dirname;
const BASE_DIR = path.join(BUILD_DIR, '..');
const args = process.argv.slice(2);
var command = args[0] ?? 'monolith';
console.log(`command is ${command}`);
const { webpack, DefinePlugin } = require('webpack');
// SMOOSIC_MODE=production builds a minified bundle without inline source maps (used by the Nuty CI build).
const isProduction = process.env.SMOOSIC_MODE === 'production';
const webpackConfig = {
  mode: isProduction ? 'production' : 'development',
  entry: path.join(BASE_DIR, 'src/application/exports.ts'),  
  output: {
    path: BUILD_DIR,
    filename: 'smoosic.js',
    library: 'Smo',
    libraryTarget: 'umd',
    libraryExport: 'default',
    globalObject: 'this'
  },
  resolve: {
    extensions: ['.ts', '.tsx','.js', '.jsx']
  },
  devtool: isProduction ? 'source-map' : 'eval-source-map',
  externals: {
    jszip: 'JSZip'
  },
  stats: {
    assets: true,
    modules: true,
    loggingDebug: true,
    errorCause: true,
    errorDetails: true,
    colors: true,
    reasons: true,
    usedExports: true
  },
  module: {      
      rules: [ {
      test: /(\.ts?$|\.js?$)/,
      include: { or: [
        path.resolve(BASE_DIR, 'src'), path.resolve(BASE_DIR, 'tests')
      ]},
      exclude: [/tools/],
      use: [
        {
        loader: 'ts-loader',
        options: {
          configFile: "tsconfig.json",
          appendTsSuffixTo: [/\.vue$/],
        }
      }
       ]
    },  {
          test: /\.vue$/,
          use: ['vue-loader'],
          exclude: /node_modules|types/
        },
      { test: /\.css$/, use: ['vue-style-loader', 'css-loader']}]
  },
  plugins: [
    new VueLoaderPlugin(),
    new DefinePlugin({
      __VUE_OPTIONS_API__ : true,
      __VUE_PROD_DEVTOOLS__ : !isProduction,
      __VUE_PROD_HYDRATION_MISMATCH_DETAILS__ : true
    }),    
    new CopyPlugin({
      patterns: [
        { from: "src/styles/", to: "styles/"}
      ]
    })
  ]
};
if (command === 'types') {
  console.log('using types file');
  webpackConfig.module.rules[0].use[0].options = {
    configFile: 'tsconfig-types.json'
  };
}
const compiler = webpack(webpackConfig);
compiler.run((err, stats) => {
  if (err) {
    console.warn(err);
    process.exitCode = 1;
    return;
  }
  if (stats.hasErrors()) {
    process.exitCode = 1;
  }
  console.log(stats.toString({
    colors: true
  }));
  console.log(new Date().toUTCString());
});
/* require('child_process').exec('node ./node_modules/webpack-cli/bin/cli.js', (error, stdout, stderr) => {
  console.log(`${stdout}`);
  console.log(new Date().toUTCString());
});  */
