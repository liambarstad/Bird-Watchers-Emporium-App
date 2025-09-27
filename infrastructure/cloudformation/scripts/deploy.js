const { execSync } = require('child_process');
const path = require('path');

console.log('🚀 Deploying Bird Watchers Emporium Frontend Infrastructure...\n');

try {
  // Build the frontend first
  console.log('📦 Building frontend...');
  execSync('npm run build', { 
    cwd: path.join(__dirname, '../../../frontend'),
    stdio: 'inherit' 
  });

  // Deploy the CloudFormation stack
  console.log('\n☁️  Deploying CloudFormation stack...');
  execSync('cdk deploy --require-approval never', {
    cwd: __dirname,
    stdio: 'inherit'
  });

  console.log('\n✅ Deployment completed successfully!');
  console.log('🌐 Your frontend should be available at the CloudFront URL shown above.');

} catch (error) {
  console.error('\n❌ Deployment failed:', error.message);
  process.exit(1);
}
