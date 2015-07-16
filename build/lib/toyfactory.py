# -*- python -*-
# ex: set syntax=python:

from buildbot.changes import filter
from buildbot.changes.gitpoller import GitPoller

from buildbot.schedulers.basic import SingleBranchScheduler
from buildbot.schedulers.forcesched import ForceScheduler

from buildbot.process.factory import BuildFactory

from buildbot.steps.source.git import Git
from buildbot.steps.shell import ShellCommand
from buildbot.steps.slave import SetPropertiesFromEnv
from buildbot.steps.transfer import FileUpload

from buildbot.config import BuilderConfig
from buildbot.process.properties import Property,Interpolate

repositoryUri='git@github.com:retran/toy-factory.git',
workingDirectory='./build/src/'

def createLinuxDevFactory():
    f = BuildFactory()

    f.addStep(Git(
        description="fetching sources",
        descriptionDone="sources",
        haltOnFailure=True,
        repourl=repositoryUri,
        mode='full',
        method='clobber',
    ))

    f.addStep(ShellCommand(
        description="fetching packages",
        descriptionDone="packages",
        haltOnFailure=True,
        command=["mono", "paket.exe", "restore"],
        workdir=workingDirectory))

    f.addStep(SetPropertyFromCommand(
        description="setting version",
        descriptionDone="version",
        haltOnFailure=True,
        command=["racket", "/home/retran/build-tools/patch-version.rkt", "-p", "linux", "-v", "0.1.4", "-b", Property("buildnumber")],
        property = "buildPostfix",
        workdir=workingDirectory))

    f.addStep(ShellCommand(
        description="building",
        descriptionDone="build",
        haltOnFailure=True,
        command=["xbuild", "CorvusAlba.ToyFactory.Linux.sln"],
        workdir=workingDirectory))

    f.addStep(ShellCommand(
        description="archiving",
        descriptionDone="archive",
        haltOnFailure=True,
        command=["tar", "-zcvf", Interpolate("toy-factory-%(prop:buildPostfix).tar.gz)"), "../bin"],
        workdir=workingDirectory))

    f.addStep(FileUpload(
        description="uploading",
        descriptionDone="upload",
        haltOnFailure=True,
        slavesrc=Interpolate("toy-factory-%(prop:buildPostfix).tar.gz)"),
        masterdest=Interpolate("~\builds\toy-factory-%(prop:buildPostfix).tar.gz)"),
        workdir=workingDirectory))

    return f

def createLinuxCIFactory():
    f = BuildFactory()

    f.addStep(Git(
        description="fetching sources",
        descriptionDone="sources",
        haltOnFailure=True,
        repourl=repositoryUri,
        mode='full',
        method='clobber',
    ))

    f.addStep(ShellCommand(
        description="fetching packages",
        descriptionDone="packages",
        haltOnFailure=True,
        command=["mono", "paket.exe", "restore"],
        workdir=workingDirectory))

    f.addStep(ShellCommand(
        description="building",
        descriptionDone="build",
        haltOnFailure=True,
        command=["xbuild", "CorvusAlba.ToyFactory.Linux.sln"],
        workdir=workingDirectory))

    return f

def configure(config):
    # pollers
    config['change_source'].append(GitPoller(
        repositoryUri,
        workdir='gitpoller-workdir',
        branch='dev',
        pollinterval=60,
        project='toy-factory-dev'
    ))

    # schedulers
    config['schedulers'].append(SingleBranchScheduler(
        name="toy-factory-dev-ci",
        change_filter=filter.ChangeFilter(branch='dev'),
        treeStableTimer=None,
        builderNames=["toy-factory-linux-ci"]))

    config['schedulers'].append(ForceScheduler(
        name="toy-factory-dev-ci-force",
        builderNames=["toy-factory-linux-ci"]))

    config['schedulers'].append(ForceScheduler(
        name="toy-factory-linux-dev-force",
        builderNames=["toy-factory-linux-dev"]))

    # builders
    config['builders'].append(BuilderConfig(
        name="toy-factory-linux-ci",
        slavenames=["linux"],
        factory=createLinuxCIFactory()))

    config['builders'].append(BuilderConfig(
        name="toy-factory-linux-dev",
        slavenames=["linux"],
        factory=createLinuxDevFactory()))
