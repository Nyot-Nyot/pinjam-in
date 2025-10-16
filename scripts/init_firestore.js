#!/usr/bin/env node
// Usage: node scripts/init_firestore.js --project <PROJECT_ID>
// This script creates harmless sentinel documents so collections appear in
// the Firestore console. It does NOT seed real application data.

const {Firestore} = require('@google-cloud/firestore');
const yargs = require('yargs/yargs');
const {hideBin} = require('yargs/helpers');

async function main() {
  const argv = yargs(hideBin(process.argv))
    .option('project', { type: 'string', demandOption: true })
    .help()
    .argv;

  const projectId = argv.project;
  console.log('Initializing Firestore structure for project:', projectId);

  const db = new Firestore({ projectId });

  const sentinelLoanRef = db.collection('loan_items').doc('_init');
  const sentinelUsersRef = db.collection('users').doc('_init');

  try {
    await sentinelLoanRef.set({
      note: 'sentinel',
      createdAt: Firestore.Timestamp ? Firestore.Timestamp.now() : new Date().toISOString(),
    }, { merge: true });
    console.log('Ensured loan_items/_init');

    await sentinelUsersRef.set({
      note: 'sentinel',
      createdAt: Firestore.Timestamp ? Firestore.Timestamp.now() : new Date().toISOString(),
    }, { merge: true });
    console.log('Ensured users/_init');

    console.log('Initialization complete. No application data was seeded.');
  } catch (e) {
    console.error('Failed to initialize Firestore:', e);
    process.exitCode = 1;
  }
}

main();
