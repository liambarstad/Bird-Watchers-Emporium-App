#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { AppStack } from './app-stack';

const app = new cdk.App();

const region = process.env.AWS_REGION;

// Get Terraform outputs from environment variables
const vpcId = process.env.VPC_ID;
const subnetId = process.env.PRIVATE_SUBNET_ID;
const vpcCidrBlock = process.env.VPC_CIDR_BLOCK;
const subnetCidrBlock = process.env.PRIVATE_SUBNET_CIDR_BLOCK;

// Create the S3 and CloudFront stack
new AppStack(app, 'BWE-App', {
  env: { region },
  vpcConfig: {
    vpcId,
    vpcCidrBlock,
    subnetId,
    subnetCidrBlock
  }
});

app.synth();
