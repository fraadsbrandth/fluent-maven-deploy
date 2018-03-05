# Fluent Maven Deploy

## Motivation & Benefits
- https://blog.philipphauer.de/version-numbers-continuous-delivery-maven-docker/
- Avoid manual maven releases
- (Avoid use of the Maven Realease Plugin)
- No ambiguous versions
- No scm tag needed in your pom.xml
- No changes/plugins needed in pom.xml -> Easily adaptable to old projects without code changes (just a properly formatted SEMVER version)

## Prerequisite
- Maven project using GIT (And authorized to push code directly to master)
- GIT installed (deploy will fail if not installed)
- Maven installed (And properly configured to be allowed to perform a deploy. Deploy will fail if not installed)
- No SNAPSHOT dependencies in the project (deploy will fail with listing of all pom's containing SNAPSHOT dependencies)
- Version on SEMVER format (deploy will fail if it is a SNAPSHOT version/ some other versioning strategy)
