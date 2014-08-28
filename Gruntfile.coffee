###
Summary
=======

This is a summary of what this Gruntfile does:

* The `grunt` default task transpiles the CoffeeScript and then starts a
  development server and a task to watch for file changes.
* When a CoffeeScript file changes, the files are linted, transpiled, and tests
  are run, in parallel.
* When a JS file changes(from CoffeeScript transpiling), the development server
  is restarted, as well as a LiveReload in the browser
* When a JS file changes the documentation is rebuilt asynchronously, and
  doesn't prevent server reloading

###
module.exports = (grunt) ->
  grunt.initConfig
    pkg: grunt.file.readJSON 'package.json'

    # Task to watch various sets of files and automatically perform actions
    # when they are changed
    watch:
      # Whenever a coffee file changes, run the concurrent:coffee task which
      # does transpiling, linting, tests, etc.
      coffee:
        files: [
          'Gruntfile.coffee',
          'src/**/*.coffee',
          'index.coffee',
        ]
        tasks: ['concurrent:coffee']
      # Whenever lib or test files are updated, rerun tests
      test:
        files: ['lib/**/*.js', 'test/**/*.coffee']
        tasks: ['test']
      # Whenever the JS files are transpiled, rebuild the documentation
      lib:
        files: ['lib/**/*.js']
        tasks: [] # ['jsdoc']

    # Task to compile src coffee files into lib JS files
    coffee:
      lib:
        expand: true  # Expands the src glob to match files dynamically
        cwd: 'src/'  # Need to use cwd or it ends up as lib/src/blah.js
        src: ['**/*.coffee']
        dest: 'lib/'
        ext: '.js'
      index:
        files:
          'index.js': 'index.coffee'

    # Task to coffeelint both tests and src files
    coffeelint:
      lib: ['src/**/*.coffee']
      test: ['test/**/*.coffee']

    # Build JSdocs
    jsdoc:
      lib:
        src: ['lib/*.js']
        dest: 'docs/'
        options:
          # This says to use the DocStrap template which is included with
          # grunt-jsdoc, for nicer documentation
          template: 'node_modules/grunt-jsdoc/node_modules/ink-docstrap/template/'
          configure: 'node_modules/grunt-jsdoc/node_modules/ink-docstrap/template/jsdoc.conf.json'

    # Mocha test task, which is run by the watch task when there are changes to
    # test or library files
    mochaTest:
      test:
        src: ['test/**/*.coffee']
        options:
          # This allows Mocha to compile the coffeescript tests directly, as
          # well as activates the fibrous API
          require: ['coffee-script/register', 'chai']
          reporter: 'spec'
          slow: 1
          bail: true

    # Define tasks which can be executed concurrently for faster builds
    concurrent:
      # This is the default "development mode" grunt task. It starts the watch
      # task, which handles compiling, linting, and test running
      dev:
        tasks: ['watch']
        options:
          logConcurrentOutput: true
      # This runs all the coffee related tasks in parallel, including linting,
      # transpiling, etc.
      coffee:
        tasks: ['coffeelint:lib', 'coffeelint:test', 'newer:coffee']

    # Tasks that set environment variables
    env:
      test:
        NODE_ENV: 'test'

  # Load all our grunt tasks
  require('load-grunt-tasks') grunt;

  # Our default grunt task compiles our coffeescript lib then runs our server
  grunt.registerTask 'default', ['coffee', 'concurrent:dev']
  grunt.registerTask 'test', ['coffee', 'env:test', 'mochaTest']

