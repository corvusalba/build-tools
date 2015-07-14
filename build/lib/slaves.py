# -*- python -*-
# ex: set syntax=python:

from buildbot.buildslave import BuildSlave

def configure(config):
    config['slaves'] = [
        BuildSlave("linux", "pass"),
        BuildSlave("windows", "pass")
    ]
