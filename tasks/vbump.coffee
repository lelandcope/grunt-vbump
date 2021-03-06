###
    Increase version number

    * grunt vbump
    * grunt vbump:build
    * grunt vbump:patch
    * grunt vbump:minor
    * grunt vbump:major

    @author Leland Cope <lelandcope@gmail.com>
###

semver      = require 'semver'
cp          = require 'child_process'
exec        = cp.exec
inquirer    = require 'inquirer'

module.exports = (grunt)->
    DESC = 'Increment the version, commit, tag and push.'

    grunt.registerTask 'vbump', DESC, (versionType = 'build', incOrCommitOnly)->
        opts = @options
            forceSameVersion:   true
            bumpVersion:        true
            files:              ['package.json']
            updateConfigs:      []
            commit:             false
            commitMessage:      '%VERSION%: '
            commitFiles:        ['package.json'] # '-a' for all files
            createTag:          false
            tagName:            '%VERSION%'
            tagMessage:         'Version %VERSION%'
            push:               false
            pushTo:             'orgin'
            gitDescribeOptions: '--tags --always --abbrev=1 --dirty=-d'

        for key, value of grunt.config ['vbump', versionType, 'options']
            opts[key] = value

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


        # Bump Version
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


        # Commit
        runIf opts.commit, ()->
            inquirer.prompt [
                name: 'commitMessage'
                message: 'Commit Message?'
                default: ''
            ], (answers)->
                command = 'git commit ' + opts.commitFiles.join(' ') + ' -m "' + answers.commitMessage + '"'

                exec command, (err, stdout, stderr)->
                    grunt.fatal 'Can not create the commit:\n  ' + stderr if err

                    grunt.log.ok 'Committed as "' + answers.commitMessage + '"'
                    next()


        # Tag
        runIf opts.createTag, ()->
            tagName     = opts.tagName.replace '%VERSION%', globalVersion
            tagMessage  = opts.tagMessage.replace '%VERSION%', globalVersion
            command     = 'git tag -a ' + tagName + ' -m "' + tagMessage + '"'

            exec command, (err, stdout, stderr)->
                grunt.fatal 'Can not create the tag:\n  ' + stderr if err

                grunt.log.ok 'Tagged as "' + tagName + '"'
                next()


        # Push
        runIf opts.push, ()->
            command = 'git push ' + opts.pushTo + ' && git push ' + opts.pushTo + ' --tags'

            exec command, (err, stdout, stderr)->
                grunt.fatal 'Can not push to ' + opts.pushTo + ':\n  ' + stderr if err

                grunt.log.ok 'Pushed to ' + opts.pushTo
                next()


        # Start the Task
        next()


