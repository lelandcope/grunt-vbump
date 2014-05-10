###
    Increase version number

    * grunt vbump
    * grunt vbump:build
    * grunt vbump:patch
    * grunt vbump:minor
    * grunt vbump:major

    @author Leland Cope <lelandcope@gmail.com>
###

semver  = require 'semver'
cp      = require 'child_process'
exec    = cp.exec

module.exports = (grunt)->
    DESC = 'Increment the version, commit, tag and push.'

    grunt.registerTask 'vbump', DESC, (versionType = 'patch', incOrCommitOnly)->
        opts = @options
            forceSameVersion:   true
            bumpVersion:        true
            files:              ['package.json']
            updateConfigs:      []
            commit:             false
            commitMessage:      'Release v%VERSION%'
            commitFiles:        ['package.json'] # '-a' for all files
            createTag:          false
            tagName:            'v%VERSION%'
            tagMessage:         'Version %VERSION%'
            push:               false
            pushTo:             ''
            gitDescribeOptions: '--tags --always --abbrev=1 --dirty=-d'

        globalVersion       = null
        exactVersionToSet   = grunt.option 'setversion'
        VERSION_REGEXP      = /([\'|\"]?version[\'|\"]?[ ]*:[ ]*[\'|\"]?)([\d||A-a|.|-]*)([\'|\"]?)/i


        done    = @async()
        queue   = []

        next    = ()->
            return done() unless queue.length
            queue.shift()()

            return

        runIf   = (condition, func)->
            queue.push func if condition

            return



        runIf opts.bumpVersion, ()->
            opts.files.forEach (file, idx)->
                version = null

                content = grunt.file.read(file).replace VERSION_REGEXP, (match, prefix, parsedVersion, suffix)->
                    if opts.forceSameVersion and globalVersion
                        version = globalVersion
                    else
                        version = exactVersionToSet or semver.inc parsedVersion, versionType
                        version = version.replace /(-0)$/i, '' unless versionType is 'build'

                    prefix + version + suffix

                grunt.fatal 'Can not find a version to bump in ' + file unless version

                grunt.file.write file, content
                grunt.log.ok 'Version bumped to ' + version + if opts.files.length > 1 then ' (in ' + file + ')' else ''

                globalVersion = version unless globalVersion

                grunt.warn 'Bumping multiple files with different versions!' unless globalVersion is version

                configProperty = opts.updateConfigs[idx]

                if configProperty
                    cfg = grunt.config configProperty

                    return grunt.warn 'Can not update "' + configProperty + '" config, it does not exist!' unless cfg

                    cfg.version = version
                    grunt.config configProperty, cfg
                    grunt.log.ok configProperty + '\'s version updated'

            next()

        # Start the Task
        next()


