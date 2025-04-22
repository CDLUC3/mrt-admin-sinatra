## Java Libraries - Tagging Conventions

- Merritt Java libraries are published as snapshots.  These snapshots are updated.
- Merritt Java Libraries are versioned via the version tag within the libraries pom.xml file.
- When breaking changes are made to a library, the developer *should* create a new version.
- Merritt services will explicitly update pom files to pull a new published snapshot of a library.

- `main` branch
  - tagged as `library.version-SNAPSHOT` in CodeArtifact
- `branch` branch
  - *requires a CodePipleline to trach changes to a feature branch in order to publish updates*
  - tagged as `library.version-SNAPSHOT` in CodeArtifact
- `tag` tag
  - tagging is not relevant for Merritt Java libraries

---

pom.xml for Jar file

```
   <packaging>jar</packaging>
    <version>3.1-SNAPSHOT</version>
    <name>UC3-mrtcore</name>
```

The version is updated with the following command:
```
mvn release:update-versions
```

---

pom.xml for referring WAR file

```
   <properties>
      <merritt-zk.version>3.0-SNAPSHOT</merritt-zk.version>
      <merritt-cloud.version>3.1-SNAPSHOT</merritt-cloud.version>
      <merritt-core.version>3.1-SNAPSHOT</merritt-core.version>
      <merritt-bom.version>3.0-SNAPSHOT</merritt-bom.version>
    </properties>
```

---