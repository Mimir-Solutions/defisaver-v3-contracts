const { guniFullTest } = require('./guni-tests');

describe('GUni full test', () => {
    it('... should do full Guni test', async () => {
        await guniFullTest();
    });
});
