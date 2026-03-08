import * as pulumi from "@pulumi/pulumi";

const config = new pulumi.Config();

const layer0 = new pulumi.StackReference(`layer0/default`);
