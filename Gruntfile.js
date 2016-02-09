module.exports = function (grunt) {
    grunt.initConfig({
        shell: {
            test: {
                options: {
                    stdout: true
                },
                command: 'powershell scripts\\test.ps1'
            },
            push: {
                command: "powershell scripts\\push.ps1 -newversion"
            },
            init: {
                command: "npm run init"
            },     
            restore: {
                command: "nmp run restore"
            }
        }
    });

    grunt.loadNpmTasks('grunt-shell');
    
    grunt.registerTask('test', ['shell:test']);
    grunt.registerTask('push', ['shell:test', 'shell:push']);
    grunt.registerTask('init', ['shell:init']);
     
}