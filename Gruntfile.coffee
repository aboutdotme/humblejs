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
  # This is used to toggle Fiber testing
  try
    require.resolve 'mocha-fibers'
    mocha_fibers = 'mocha-fibers'
  catch err
    mocha_fibers = null

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
        files: ['test/**/*.coffee', 'index.coffee']
        tasks: ['test']
      # Whenever the docs are changed we rebuild them
      docs:
        files: ['docs/**/*.rst']
        # options: livereload: true
        tasks: ['shell:sphinx']

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
      index: ['index.coffee']
      test: ['test/**/*.coffee']

    # Task to build documentation
    shell:
      sphinx:
        command: "sphinx-build docs/ docs/_build"

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
          slow: 2
          ui: mocha_fibers
          # bail: true  # Stop after first failure

    # Define tasks which can be executed concurrently for faster builds
    concurrent:
      # This is the default "development mode" grunt task. It starts the watch
      # task, which handles compiling, linting, and test running
      dev:
        tasks: ['watch']
        options:
          logConcurrentOutput: true
      # This runs all the coffee related tasks in parallel
      coffee:
        tasks: ['coffeelint:index', 'coffeelint:test']

    # Tasks that set environment variables
    env:
      test:
        NODE_ENV: 'test'

    # Task to clean up built files
    clean: ['index.js', 'lib/*.js']

  # Load all our grunt tasks
  require('load-grunt-tasks') grunt;

  # We rename the release task so we can use it in our custom task (below)
  grunt.renameTask 'release', 'publish'

  # Our default grunt task sets up watches to run coffeelint and tests
  grunt.registerTask 'default', ['concurrent:dev']
  # Our test task sets the environment to be test, and then runs our unit tests
  grunt.registerTask 'test', ['env:test', 'mochaTest']

  # This is our custom release task that ensures coffeescript compiles first
  grunt.registerTask 'release', "compile coffeescript, bump version, git tag,
    git push, npm publish", (target) ->
    target ?= 'patch'
    grunt.task.run ['coffeelint', 'test', 'coffee', "publish:#{target}",
      'clean']


