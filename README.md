# Fluent Maven Deploy

## Motivation & Benefits
- https://blog.philipphauer.de/version-numbers-continuous-delivery-maven-docker/
- Avoid manual maven releases
- (Avoid use of the Maven Realease Plugin)
- No ambiguous versions (read SNAPSHOT)
- No upstream/downstream/scheduled builds needed when no SNAPSHOT's are in use
- No scm tag needed in your pom.xml (you can checkout from the GIT sha)
- No changes/plugins needed in pom.xml -> Easily adaptable to old projects without code changes (just a properly formatted SEMVER version)

## Prerequisite
- Maven project using GIT (And authorized to push code directly to master)
- GIT installed (deploy will fail if not installed)
- Maven installed (And properly configured to be allowed to perform a deploy. Deploy will fail if not installed)
- No SNAPSHOT dependencies in the project (deploy will fail with listing of all pom's containing SNAPSHOT dependencies)
- Version on SEMVER format (deploy will fail if it is a SNAPSHOT version/ some other versioning strategy)

## Version format (w.x.y.z)
- w.x.y is on Semver format (https://semver.org/)
- z = GIT short sha (https://git-scm.com/book/id/v2/Git-Tools-Revision-Selection#_short_sha)

## Triggering deploy
If the latest commit contains #patch, #minor or #major

## Example use
### Install
Install locally with the correct version a deploy in this state will produce

```bash
    git clone https://github.com/fraadsbrandth/fluent-maven-deploy.git
    cd my-maven-project
    ./../fluent-maven-deploy/fluent-maven-deploy.sh --goal="install"
```
### Deploy

```bash
    git clone https://github.com/fraadsbrandth/fluent-maven-deploy.git
    cd my-maven-project
    # The options paramteter is optionl, but here used to specifcy repository to avoid having it in you pom
    ./../fluent-maven-deploy/fluent-maven-deploy.sh --options="-DaltDeploymentRepository=$DEPLOYMENT_REPOSITORY"
```
