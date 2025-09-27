#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { S3Stack } from './s3-stack';

const app = new cdk.App();

// Get environment variables or use defaults
const account = process.env.CDK_DEFAULT_ACCOUNT || '123456789012';
const region = process.env.CDK_DEFAULT_REGION || 'us-east-1';
const bucketName = process.env.BUCKET_NAME || `bird-watchers-emporium-frontend-${account}-${region}`;

// Create the S3 and CloudFront stack
new S3Stack(app, 'BirdWatchersEmporiumFrontendStack', {
  env: { account, region },
  bucketName,
  description: 'Bird Watchers Emporium Frontend Infrastructure',
});

app.synth();
